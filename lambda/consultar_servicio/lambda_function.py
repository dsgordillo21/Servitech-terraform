"""Consulta un servicio en PostgreSQL desde un evento de API Gateway."""

from datetime import datetime
import json
import os

import boto3
import psycopg2


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
            "Content-Type": "application/json",
        },
        "body": json.dumps(body),
    }


def get_service_id(event):
    if not isinstance(event, dict):
        raise ValueError("El ID debe ser un entero positivo.")

    parameters = event.get("pathParameters")
    if not isinstance(parameters, dict):
        raise ValueError("El ID debe ser un entero positivo.")

    value = parameters.get("id")
    if isinstance(value, bool) or not isinstance(value, (str, int)):
        raise ValueError("El ID debe ser un entero positivo.")
    if isinstance(value, str) and not value.strip().isdecimal():
        raise ValueError("El ID debe ser un entero positivo.")

    try:
        service_id = int(value)
    except ValueError:
        raise ValueError("El ID debe ser un entero positivo.") from None
    if service_id <= 0:
        raise ValueError("El ID debe ser un entero positivo.")

    return service_id


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
        service_id = get_service_id(event)
    except ValueError as error:
        return response(400, {"message": str(error)})

    connection = None
    try:
        connection = get_connection()
        with connection.cursor() as cursor:
            ensure_schema(cursor)
            cursor.execute(
                """
                SELECT
                    id,
                    cliente,
                    equipo,
                    descripcion,
                    fecha_registro
                FROM servicios
                WHERE id = %s;
                """,
                (service_id,),
            )
            service = cursor.fetchone()

        connection.commit()
        if service is None:
            return response(404, {"message": "Servicio no encontrado"})

        registered_at = service[4]
        if isinstance(registered_at, datetime):
            registered_at = registered_at.isoformat()

        return response(
            200,
            {
                "id": service[0],
                "cliente": service[1],
                "equipo": service[2],
                "descripcion": service[3],
                "fecha_registro": registered_at,
            },
        )
    except Exception:
        if connection is not None:
            try:
                connection.rollback()
            except Exception:
                print("ConsultarServicio: no se pudo revertir la transacción.")
        print("ConsultarServicio: error interno al consultar el servicio.")
        return response(500, {"message": "Error interno al consultar el servicio."})
    finally:
        if connection is not None:
            try:
                connection.close()
            except Exception:
                print("ConsultarServicio: no se pudo cerrar la conexión.")
