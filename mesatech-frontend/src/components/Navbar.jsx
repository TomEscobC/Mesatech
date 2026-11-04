import React from "react";
import { Cloud, LogIn, LogOut, ShieldCheck } from "lucide-react";

export const Navbar = ({
  isAuthenticated,
  user,
  userRole,
  onLogin,
  onLogout,
  onOpenTokenModal
}) => {
  const getRoleBadgeStyle = (role) => {
    switch (role) {
      case "Administrador":
        return { backgroundColor: "#7c3aed", color: "white" };
      case "Operador":
        return { backgroundColor: "#d97706", color: "white" };
      case "Cliente":
      default:
        return { backgroundColor: "#0284c7", color: "white" };
    }
  };

  return (
    <header className="navbar">
      <div className="nav-brand">
        <Cloud size={28} color="#0284c7" />
        <div>
          MesaTech <span>Cloud</span>
        </div>
        {isAuthenticated && userRole && (
          <span className="nav-role-badge" style={getRoleBadgeStyle(userRole)}>
            Cargo: {user?.cargo || userRole}
          </span>
        )}
      </div>

      <div className="nav-actions">
        {isAuthenticated ? (
          <>
            {/* Inspector de Claims del Token */}
            <button className="btn btn-outline btn-sm" onClick={onOpenTokenModal}>
              <ShieldCheck size={16} color="#0284c7" />
              Inspeccionar Claims JWT
            </button>

            {/* Perfil del Usuario */}
            <div className="user-profile-badge">
              <div
                className="user-avatar"
                style={{
                  backgroundColor: userRole === "Administrador" ? "#7c3aed" : userRole === "Operador" ? "#d97706" : "#0284c7"
                }}
              >
                {user?.name ? user.name.charAt(0).toUpperCase() : "U"}
              </div>
              <div className="user-details">
                <span className="user-name" style={{ display: "flex", alignItems: "center", gap: "0.4rem" }}>
                  {user?.name || "Usuario Autenticado"}
                  <span style={{
                    fontSize: "0.68rem",
                    padding: "0.1rem 0.4rem",
                    borderRadius: "0.25rem",
                    fontWeight: "bold",
                    backgroundColor: userRole === "Administrador" ? "#f3e8ff" : userRole === "Operador" ? "#fef3c7" : "#e0f2fe",
                    color: userRole === "Administrador" ? "#6b21a8" : userRole === "Operador" ? "#b45309" : "#0369a1",
                    border: `1px solid ${userRole === "Administrador" ? "#d8b4fe" : userRole === "Operador" ? "#fde68a" : "#bae6fd"}`
                  }}>
                    {user?.cargo || userRole || "Cliente"}
                  </span>
                </span>
                <span className="user-email">{user?.username || user?.email || "usuario@mesatech.cloud"}</span>
              </div>
            </div>

            {/* Botón Logout */}
            <button className="btn btn-danger btn-sm" onClick={onLogout} title="Cerrar Sesión">
              <LogOut size={16} />
              Salir
            </button>
          </>
        ) : (
          <div style={{ display: "flex", gap: "0.5rem", alignItems: "center" }}>
            {/* Botón de acceso con Microsoft Entra ID */}
            <button className="btn btn-primary" onClick={onLogin}>
              <LogIn size={18} />
              Iniciar Sesión (Entra ID)
            </button>
          </div>
        )}
      </div>
    </header>
  );
};
