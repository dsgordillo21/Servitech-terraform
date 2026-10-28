"use strict";

// Reemplazar por la URL HTTPS real de API Gateway, incluido el stage /dev.
const API_URL = "API_URL_PENDIENTE";
const REQUEST_TIMEOUT_MS = 20000;

const registerForm = document.getElementById("register-form");
const lookupForm = document.getElementById("lookup-form");
const registerFields = document.getElementById("register-fields");
const lookupFields = document.getElementById("lookup-fields");
const registerButton = document.getElementById("register-button");
const lookupButton = document.getElementById("lookup-button");
const registerStatus = document.getElementById("register-status");
const lookupStatus = document.getElementById("lookup-status");
const serviceIdInput = document.getElementById("servicio-id");
const serviceResult = document.getElementById("service-result");
const registrationInputs = ["cliente", "equipo", "descripcion"].map((id) => document.getElementById(id));

function configuredApiUrl() {
  try {
    const url = new URL(API_URL);
    if (url.protocol !== "https:" || url.search || url.hash || url.username || url.password) return null;
    return url.href.replace(/\/+$/u, "");
  } catch {
    return null;
  }
}

const apiBase = configuredApiUrl();
document.getElementById("api-notice").hidden = Boolean(apiBase);

function showStatus(element, message, state = "error") {
  element.textContent = message;
  element.dataset.state = state;
}

function requireApi(status) {
  if (apiBase) return true;
  showStatus(status, "La API aún no está configurada. El equipo debe completar la conexión antes de continuar.");
  return false;
}

function setLoading(form, fields, button, loading, idleText, loadingText) {
  fields.disabled = loading;
  form.setAttribute("aria-busy", String(loading));
  button.textContent = loading ? loadingText : idleText;
}

function validId(value) {
  return Number.isSafeInteger(value) && value > 0;
}

async function request(path, options = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const response = await fetch(`${apiBase}${path}`, {
      ...options,
      headers: { Accept: "application/json", ...options.headers },
      signal: controller.signal,
    });
    // API Gateway entrega el body JSON directamente, sin envolverlo en statusCode/body.
    const body = await response.json().catch(() => null);
    return { status: response.status, body };
  } finally {
    clearTimeout(timeout);
  }
}

for (const input of [...registrationInputs, serviceIdInput]) {
  input.addEventListener("input", () => input.setCustomValidity(""));
}

registerForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (registerFields.disabled) return;

  for (const input of registrationInputs) {
    // Conserva los saltos de línea de la descripción; normaliza espacios horizontales.
    input.value = input.value.trim().replace(/[^\S\r\n]+/gu, " ");
    input.setCustomValidity(input.value ? "" : "Completa este campo con texto.");
  }
  if (!registerForm.reportValidity() || !requireApi(registerStatus)) return;

  const payload = Object.fromEntries(registrationInputs.map((input) => [input.name, input.value]));
  setLoading(registerForm, registerFields, registerButton, true, "Registrar servicio", "Registrando…");
  showStatus(registerStatus, "Registrando el servicio…", "loading");

  try {
    const { status, body } = await request("/servicios", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (status === 201) {
      if (!validId(body?.id)) {
        showStatus(registerStatus, "La API confirmó el registro, pero no devolvió un ID válido. Consulta con el equipo antes de repetir el envío.");
        return;
      }
      showStatus(registerStatus, `Servicio registrado correctamente. ID: ${body.id}. Guarda este número para consultarlo.`, "success");
      registerForm.reset();
      serviceIdInput.value = String(body.id);
      serviceIdInput.setCustomValidity("");
    } else if (status === 400) {
      showStatus(registerStatus, typeof body?.message === "string" ? body.message : "Revisa los datos del servicio e inténtalo de nuevo.");
    } else if (status === 500) {
      showStatus(registerStatus, "El servidor no pudo registrar el servicio. Inténtalo de nuevo más tarde.");
    } else {
      showStatus(registerStatus, `No se pudo confirmar el registro (HTTP ${status}). Consulta con el equipo antes de repetir el envío.`);
    }
  } catch (error) {
    const reason = error.name === "AbortError" ? "La API tardó demasiado en responder." : "No se pudo conectar con la API.";
    showStatus(registerStatus, `${reason} No se pudo confirmar el registro; verifica con el equipo si se guardó antes de repetir el envío.`);
  } finally {
    setLoading(registerForm, registerFields, registerButton, false, "Registrar servicio", "Registrando…");
  }
});

lookupForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (lookupFields.disabled) return;
  serviceResult.hidden = true;
  serviceIdInput.value = serviceIdInput.value.trim();
  const id = Number(serviceIdInput.value);
  serviceIdInput.setCustomValidity(/^\d+$/u.test(serviceIdInput.value) && validId(id) ? "" : "Ingresa un ID entero positivo.");
  if (!lookupForm.reportValidity() || !requireApi(lookupStatus)) return;

  setLoading(lookupForm, lookupFields, lookupButton, true, "Consultar", "Consultando…");
  showStatus(lookupStatus, "Consultando el servicio…", "loading");

  try {
    const { status, body } = await request(`/servicios/${id}`);
    if (status === 200) {
      const textFields = ["cliente", "equipo", "descripcion", "fecha_registro"];
      if (!validId(body?.id) || body.id !== id || !textFields.every((field) => typeof body[field] === "string")) {
        showStatus(lookupStatus, "La API devolvió datos incompletos o inválidos para este servicio.");
        return;
      }
      for (const field of ["id", ...textFields]) {
        document.getElementById(`result-${field}`).textContent = String(body[field]);
      }
      serviceResult.hidden = false;
      showStatus(lookupStatus, "Servicio encontrado. Los datos se muestran a continuación.", "success");
    } else if (status === 404) {
      showStatus(lookupStatus, "No se encontró un servicio con ese ID.");
    } else if (status === 400) {
      showStatus(lookupStatus, "La API rechazó el ID. Ingresa un entero positivo válido.");
    } else if (status === 500) {
      showStatus(lookupStatus, "El servidor no pudo consultar el servicio. Inténtalo de nuevo más tarde.");
    } else {
      showStatus(lookupStatus, `No se pudo consultar el servicio (HTTP ${status}). Inténtalo de nuevo más tarde.`);
    }
  } catch (error) {
    showStatus(lookupStatus, error.name === "AbortError" ? "La API tardó demasiado en responder. Inténtalo de nuevo." : "No se pudo conectar con la API. Revisa tu conexión o consulta con el equipo.");
  } finally {
    setLoading(lookupForm, lookupFields, lookupButton, false, "Consultar", "Consultando…");
  }
});
