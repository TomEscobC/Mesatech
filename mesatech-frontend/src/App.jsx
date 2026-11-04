import React, { useState, useEffect } from "react";
import { useMsal, useIsAuthenticated } from "@azure/msal-react";
import { loginRequest, ROLES } from "./auth/authConfig";
import { setMsalInstance, acquireApiToken } from "./services/apiService";
import { Navbar } from "./components/Navbar";
import { TokenClaimsModal } from "./components/TokenClaimsModal";
import { UnauthenticatedHero } from "./views/UnauthenticatedHero";
import { ClienteDashboard } from "./views/ClienteDashboard";
import { OperadorDashboard } from "./views/OperadorDashboard";
import { AdminDashboard } from "./views/AdminDashboard";

// Decodifica el payload de un JWT (solo para mostrar claims; la validación la hacen API Gateway y el BFF)
const decodeJwtPayload = (jwt) => {
  const part = jwt.split(".")[1];
  const b64 = part.replace(/-/g, "+").replace(/_/g, "/");
  const json = decodeURIComponent(
    atob(b64).split("").map((c) => "%" + c.charCodeAt(0).toString(16).padStart(2, "0")).join("")
  );
  return JSON.parse(json);
};

// Prioridad de roles si el token trae más de uno
const ROLE_PRIORITY = [ROLES.ADMINISTRADOR, ROLES.OPERADOR, ROLES.CLIENTE];

function App() {
  const { instance, accounts } = useMsal();
  const isAuthenticated = useIsAuthenticated();

  const [currentUser, setCurrentUser] = useState(null);
  const [activeRole, setActiveRole] = useState(null);
  const [tokenClaims, setTokenClaims] = useState(null);
  const [rawToken, setRawToken] = useState(null);
  const [isTokenModalOpen, setIsTokenModalOpen] = useState(false);
  const [authError, setAuthError] = useState(null);

  // Registrar la instancia de MSAL en el servicio Axios
  useEffect(() => {
    setMsalInstance(instance);
  }, [instance]);

  // Con sesión MSAL activa: obtener el access token de la API y leer rol y claims DEL TOKEN
  useEffect(() => {
    if (!isAuthenticated || accounts.length === 0) {
      setCurrentUser(null);
      setActiveRole(null);
      setTokenClaims(null);
      setRawToken(null);
      return;
    }
    let cancelled = false;
    const account = accounts[0];
    (async () => {
      try {
        const accessToken = await acquireApiToken();
        if (cancelled || !accessToken) return;
        const claims = decodeJwtPayload(accessToken);
        const tokenRoles = Array.isArray(claims.roles) ? claims.roles : [];
        const role = ROLE_PRIORITY.find((r) => tokenRoles.includes(r)) || null;
        setRawToken(accessToken);
        setTokenClaims(claims);
        setCurrentUser({
          name: account.name || claims.name || "Usuario",
          username: account.username || claims.preferred_username || "",
          cargo: role || "Sin rol asignado",
          roles: tokenRoles
        });
        setActiveRole(role);
        if (!role) {
          setAuthError("El token no contiene ninguno de los roles esperados (Cliente, Operador, Administrador). Solicite la asignación de un rol en Entra ID.");
        }
      } catch (err) {
        console.error("No se pudo obtener el access token de la API:", err);
        setAuthError(err.errorMessage || err.message || String(err));
      }
    })();
    return () => { cancelled = true; };
  }, [isAuthenticated, accounts]);

  // Iniciar sesión con Microsoft Entra ID vía popup
  const handleLogin = async () => {
    setAuthError(null);
    try {
      await instance.loginPopup(loginRequest);
    } catch (error) {
      console.error("Error al iniciar sesión con MSAL:", error);
      setAuthError(error.errorMessage || error.message || String(error));
    }
  };

  // Alternativa vía redirect (si el navegador bloquea popups)
  const handleLoginRedirect = async () => {
    setAuthError(null);
    try {
      await instance.loginRedirect(loginRequest);
    } catch (error) {
      console.error("Error en loginRedirect:", error);
      setAuthError(error.errorMessage || error.message || String(error));
    }
  };

  // Cerrar sesión (limpia la sesión en Entra ID)
  const handleLogout = () => {
    setCurrentUser(null);
    setActiveRole(null);
    instance.logoutPopup().catch((e) => console.error(e));
  };

  return (
    <div className="app-container">
      <Navbar
        isAuthenticated={isAuthenticated}
        user={currentUser}
        userRole={activeRole}
        onLogin={handleLogin}
        onLogout={handleLogout}
        onOpenTokenModal={() => setIsTokenModalOpen(true)}
      />

      <main className="main-content">
        {authError && (
          <div style={{
            maxWidth: "1000px",
            margin: "0 auto 1.5rem auto",
            backgroundColor: "#fef2f2",
            border: "1px solid #f87171",
            borderRadius: "0.5rem",
            padding: "1rem 1.25rem",
            color: "#991b1b"
          }}>
            <h4 style={{ margin: "0 0 0.5rem 0", fontWeight: "bold" }}>⚠️ Diagnóstico de Autenticación Entra ID</h4>
            <p style={{ margin: "0 0 0.75rem 0", fontSize: "0.9rem", fontFamily: "monospace" }}>{authError}</p>
            <div style={{ display: "flex", gap: "0.75rem", alignItems: "center" }}>
              <button
                onClick={handleLoginRedirect}
                style={{
                  backgroundColor: "#dc2626",
                  color: "white",
                  border: "none",
                  padding: "0.4rem 0.8rem",
                  borderRadius: "0.375rem",
                  cursor: "pointer",
                  fontSize: "0.85rem",
                  fontWeight: "500"
                }}
              >
                Probar inicio con Redirección (Sin Popup)
              </button>
              <button
                onClick={() => setAuthError(null)}
                style={{
                  backgroundColor: "transparent",
                  border: "1px solid #dc2626",
                  color: "#dc2626",
                  padding: "0.4rem 0.8rem",
                  borderRadius: "0.375rem",
                  cursor: "pointer",
                  fontSize: "0.85rem"
                }}
              >
                Cerrar Aviso
              </button>
            </div>
          </div>
        )}

        {!isAuthenticated ? (
          <UnauthenticatedHero
            onLogin={handleLogin}
          />
        ) : (
          <>
            {activeRole === ROLES.CLIENTE && (
              <ClienteDashboard currentUser={currentUser} />
            )}
            {activeRole === ROLES.OPERADOR && (
              <OperadorDashboard currentUser={currentUser} />
            )}
            {activeRole === ROLES.ADMINISTRADOR && (
              <AdminDashboard currentUser={currentUser} />
            )}
          </>
        )}
      </main>

      {/* Modal Inspector de Token JWT */}
      <TokenClaimsModal
        isOpen={isTokenModalOpen}
        onClose={() => setIsTokenModalOpen(false)}
        claims={tokenClaims}
        rawToken={rawToken}
      />
    </div>
  );
}

export default App;
