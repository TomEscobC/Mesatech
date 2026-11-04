import axios from "axios";
import { InteractionRequiredAuthError } from "@azure/msal-browser";
import { tokenRequest } from "../auth/authConfig";

// El frontend consume el backend SOLO a través de AWS API Gateway (HTTP API).
export const API_BASE_URL = process.env.REACT_APP_API_GATEWAY_URL || "http://localhost:8080";

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    "Content-Type": "application/json",
    "Accept": "application/json"
  }
});

let globalMsalInstance = null;

export const setMsalInstance = (instance) => {
  globalMsalInstance = instance;
};

/**
 * Adquiere el ACCESS TOKEN de la API (scope access_as_user) para la cuenta activa.
 * Es el token que valida API Gateway (JWT Authorizer) y luego el BFF.
 * Nunca se envía el ID token a la API.
 */
export const acquireApiToken = async () => {
  if (!globalMsalInstance) return null;
  const account = globalMsalInstance.getActiveAccount() || globalMsalInstance.getAllAccounts()[0];
  if (!account) return null;
  try {
    const res = await globalMsalInstance.acquireTokenSilent({ ...tokenRequest, account });
    return res.accessToken;
  } catch (err) {
    if (err instanceof InteractionRequiredAuthError) {
      const res = await globalMsalInstance.acquireTokenPopup({ ...tokenRequest, account });
      return res.accessToken;
    }
    throw err;
  }
};

// Interceptor: adjunta Authorization: Bearer <access_token> en cada llamada
apiClient.interceptors.request.use(
  async (config) => {
    const token = await acquireApiToken();
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// --- Servicios de Solicitudes (los errores del backend se propagan: no hay datos simulados) ---
export const ticketService = {
  listarV1: (params) => apiClient.get("/v1/solicitudes", { params }),
  listarV2: (params) => apiClient.get("/v2/solicitudes", { params }),
  // Categorías disponibles en Solicitudes (copia local recibida por RabbitMQ)
  listarCategoriasLocales: () => apiClient.get("/v1/solicitudes/categorias"),
  obtenerPorIdV1: (id) => apiClient.get(`/v1/solicitudes/${id}`),
  obtenerPorIdV2: (id) => apiClient.get(`/v2/solicitudes/${id}`),
  crear: (data) => apiClient.post("/v1/solicitudes", data),
  cambiarEstado: (id, data) => apiClient.put(`/v1/solicitudes/${id}/estado`, data),
  asignarOperador: (id, data) => apiClient.put(`/v1/solicitudes/${id}/asignar`, data)
};

// --- Servicios de Catálogo ---
export const catalogService = {
  listarCategorias: (soloActivas = false) => apiClient.get("/v1/catalogo/categorias", { params: { soloActivas } }),
  crearCategoria: (data) => apiClient.post("/v1/catalogo/categorias", data),
  actualizarCategoria: (id, data) => apiClient.put(`/v1/catalogo/categorias/${id}`, data),
  eliminarCategoria: (id) => apiClient.delete(`/v1/catalogo/categorias/${id}`),
  listarPrioridades: (soloActivas = false) => apiClient.get("/v1/catalogo/prioridades", { params: { soloActivas } }),
  crearPrioridad: (data) => apiClient.post("/v1/catalogo/prioridades", data),
  actualizarPrioridad: (id, data) => apiClient.put(`/v1/catalogo/prioridades/${id}`, data),
  eliminarPrioridad: (id) => apiClient.delete(`/v1/catalogo/prioridades/${id}`)
};

// --- Servicio de Inspección de Token / Perfil ---
export const authService = {
  obtenerPerfilActual: () => apiClient.get("/api/auth/me")
};

export default apiClient;
