"""Registra un servicio en PostgreSQL desde un evento de API Gateway."""

import json
import os

import boto3
import psycopg2


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Access-Control-Allow-Origin": "*",
            "Content-Type": "application/json",
        },
        "body": json.dumps(body),
    }


def get_request_body(event):
    if not isinstance(event, dict) or event.get("body") is None:
        raise ValueError("El body es obligatorio.")

    body = event["body"]
    if isinstance(body, str):
        try:
            body = json.loads(body)
        except json.JSONDecodeError:
            raise ValueError("El body debe contener JSON válido.") from None

    if not isinstance(body, dict):
        raise ValueError("El body debe ser un objeto JSON.")

    for field in ("cliente", "equipo", "descripcion"):
        value = body.get(field)
        if not isinstance(value, str) or not value.strip():
            raise ValueError(f"El campo {field} debe ser un texto no vacío.")

    return body


def get_database_credentials(secret_arn):
    client = boto3.client("secretsmanager")
    secret = client.get_secret_value(SecretId=secret_arn)
    credentials = json.loads(secret["SecretString"])

    if not isinstance(credentials, dict):
        raise ValueError("Formato de credenciales inválido.")

    for field in ("username", "password"):
        value = credentials.get(field)
        if not isinstance(value, str) or not value.strip():
            raise ValueError("Credenciales incompletas.")

    return credentials


def get_connection():
    config = {}
    for name in ("DB_HOST", "DB_PORT", "DB_NAME", "DB_SECRET_ARN"):
        value = os.environ[name]
        if not value.strip():
            raise ValueError("Configuración de base de datos incompleta.")
        config[name] = value

    credentials = get_database_credentials(config["DB_SECRET_ARN"])
    return psycopg2.connect(
        host=config["DB_HOST"],
        port=int(config["DB_PORT"]),
        dbname=config["DB_NAME"],
        user=credentials["username"],
        password=credentials["password"],
        connect_timeout=5,
    )


def ensure_schema(cursor):
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS servicios (
            id SERIAL PRIMARY KEY,
            cliente VARCHAR(150) NOT NULL,
            equipo VARCHAR(150) NOT NULL,
            descripcion TEXT NOT NULL,
            fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        """
    )


def lambda_handler(event, context):
    try:
        body = get_request_body(event)
    except ValueError as error:
        return response(400, {"message": str(error)})

    connection = None
    try:
        connection = get_connection()
        with connection.cursor() as cursor:
            ensure_schema(cursor)
            cursor.execute(
                """
                INSERT INTO servicios (cliente, equipo, descripcion)
                VALUES (%s, %s, %s)
                RETURNING id;
                """,
                (body["cliente"], body["equipo"], body["descripcion"]),
            )
            service_id = cursor.fetchone()[0]

        connection.commit()
        return response(
            201,
            {"id": service_id, "message": "Servicio registrado correctamente"},
        )
    except Exception:
        if connection is not None:
            try:
                connection.rollback()
            except Exception:
                print("RegistrarServicio: no se pudo revertir la transacción.")
        print("RegistrarServicio: error interno al registrar el servicio.")
        return response(500, {"message": "Error interno al registrar el servicio."})
    finally:
        if connection is not None:
            try:
                connection.close()
            except Exception:
                print("RegistrarServicio: no se pudo cerrar la conexión.")
