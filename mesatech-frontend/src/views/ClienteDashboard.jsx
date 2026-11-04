import React, { useState, useEffect } from "react";
import { ticketService, catalogService } from "../services/apiService";
import { StatusBadge } from "../components/StatusBadge";
import { WorkflowStepper } from "../components/WorkflowStepper";
import { PlusCircle, RefreshCw, AlertCircle, CheckCircle2, Ticket } from "lucide-react";

export const ClienteDashboard = ({ currentUser }) => {
  const [solicitudes, setSolicitudes] = useState([]);
  const [categorias, setCategorias] = useState([]);
  const [prioridades, setPrioridades] = useState([]);
  const [loading, setLoading] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [mensaje, setMensaje] = useState(null);

  const [formData, setFormData] = useState({
    titulo: "",
    descripcion: "",
    categoriaId: "",
    prioridad: ""
  });

  useEffect(() => {
    cargarDatos();
  }, []);

  const cargarDatos = async () => {
    setLoading(true);
    try {
      const [ticketsRes, catRes, prioRes] = await Promise.all([
        ticketService.listarV1(),
        ticketService.listarCategoriasLocales(),
        catalogService.listarPrioridades(true)
      ]);
      setSolicitudes(Array.isArray(ticketsRes.data) ? ticketsRes.data : []);
      setCategorias(Array.isArray(catRes.data) ? catRes.data : []);
      setPrioridades(Array.isArray(prioRes.data) ? prioRes.data : []);
      if (catRes.data?.length > 0 && !formData.categoriaId) {
        setFormData(prev => ({ ...prev, categoriaId: catRes.data[0].categoriaId }));
      }
      if (prioRes.data?.length > 0 && !formData.prioridad) {
        setFormData(prev => ({ ...prev, prioridad: prioRes.data[0].nombre }));
      }
    } catch (err) {
      console.warn("Aviso al cargar datos:", err);
      // Evitar mensaje intrusivo de 401
    } finally {
      setLoading(false);
    }
  };

  const handleCrear = async (e) => {
    e.preventDefault();
    try {
      await ticketService.crear({
        ...formData,
        usuarioSolicitante: currentUser?.username || currentUser?.email || "cliente.prueba@curzua1.onmicrosoft.com"
      });
      setMensaje({ tipo: "success", texto: "¡Solicitud registrada exitosamente en estado CREADA!" });
      setShowModal(false);
      setFormData({ titulo: "", descripcion: "", categoriaId: categorias[0]?.categoriaId || "", prioridad: prioridades[0]?.nombre || "" });
      cargarDatos();
    } catch (err) {
      setMensaje({ tipo: "error", texto: "Error al crear la solicitud: " + (err.response?.data?.message || err.message) });
    }
  };

  return (
    <div>
      <div className="card">
        <div className="card-header" style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", flexWrap: "wrap", gap: "1rem" }}>
          <div>
            <div style={{ display: "flex", alignItems: "center", gap: "0.6rem" }}>
              <h2 className="card-title" style={{ margin: 0 }}>
                <Ticket size={22} color="#0284c7" />
                Panel de Solicitudes
              </h2>
              <span style={{
                backgroundColor: "#0284c7",
                color: "white",
                padding: "0.2rem 0.6rem",
                borderRadius: "0.25rem",
                fontSize: "0.75rem",
                fontWeight: "bold"
              }}>
                Cargo: {currentUser?.cargo || "Cliente"}
              </span>
            </div>
            <p style={{ fontSize: "0.85rem", color: "var(--text-muted)", marginTop: "0.35rem" }}>
              Usuario: <strong>{currentUser?.name || "Juan Cliente"}</strong> ({currentUser?.username || "cliente.prueba@curzua1.onmicrosoft.com"})
            </p>
          </div>
          <div style={{ display: "flex", gap: "0.5rem" }}>
            <button className="btn btn-outline btn-sm" onClick={cargarDatos} disabled={loading}>
              <RefreshCw size={14} className={loading ? "spin" : ""} />
              Actualizar
            </button>
            <button className="btn btn-primary" onClick={() => setShowModal(true)}>
              <PlusCircle size={16} />
              Nueva Solicitud
            </button>
          </div>
        </div>

        {mensaje && (
          <div className={mensaje.tipo === "success" ? "alert alert-success" : "alert alert-danger"}>
            {mensaje.tipo === "success" ? <CheckCircle2 size={18} /> : <AlertCircle size={18} />}
            {mensaje.texto}
          </div>
        )}

        <div className="table-responsive">
          <table className="data-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>Título</th>
                <th>Categoría</th>
                <th>Prioridad</th>
                <th>Estado Actual</th>
                <th>Flujo de Vida</th>
                <th>Fecha de Creación</th>
              </tr>
            </thead>
            <tbody>
              {solicitudes.length === 0 ? (
                <tr>
                  <td colSpan="7" style={{ textAlign: "center", padding: "2rem", color: "var(--text-muted)" }}>
                    {loading ? "Cargando solicitudes..." : "No tienes solicitudes registradas aún. Haz clic en 'Nueva Solicitud' para crear una."}
                  </td>
                </tr>
              ) : (
                solicitudes.map((sol) => (
                  <tr key={sol.id}>
                    <td style={{ fontWeight: 700, color: "var(--text-muted)" }}>#{sol.id}</td>
                    <td>
                      <div style={{ fontWeight: 600, color: "var(--text-main)" }}>{sol.titulo}</div>
                      <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", maxWidth: "300px" }}>{sol.descripcion}</div>
                    </td>
                    <td>{sol.categoria}</td>
                    <td>
                      <span style={{ fontWeight: 600 }}>{sol.prioridad}</span>
                    </td>
                    <td>
                      <StatusBadge estado={sol.estado} />
                    </td>
                    <td>
                      <WorkflowStepper estadoActual={sol.estado} />
                    </td>
                    <td style={{ fontSize: "0.8rem", color: "var(--text-muted)" }}>
                      {sol.fechaCreacion ? new Date(sol.fechaCreacion).toLocaleString() : "N/A"}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal para Crear Solicitud */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">Registrar Nueva Solicitud de Soporte</h3>
              <button className="btn btn-outline btn-sm" onClick={() => setShowModal(false)}>✕</button>
            </div>
            <form onSubmit={handleCrear}>
              <div className="form-group">
                <label className="form-label">Título del Requerimiento *</label>
                <input
                  type="text"
                  className="form-control"
                  required
                  placeholder="Ej: Falla en conexión a red cableada"
                  value={formData.titulo}
                  onChange={(e) => setFormData({ ...formData, titulo: e.target.value })}
                />
              </div>

              <div className="form-group">
                <label className="form-label">Descripción Detallada *</label>
                <textarea
                  className="form-control"
                  rows="3"
                  required
                  placeholder="Explique claramente el síntoma o necesidad para que el operador pueda atenderlo"
                  value={formData.descripcion}
                  onChange={(e) => setFormData({ ...formData, descripcion: e.target.value })}
                />
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1rem" }}>
                <div className="form-group">
                  <label className="form-label">Categoría *</label>
                  <select
                    className="form-control"
                    value={formData.categoriaId}
                    onChange={(e) => setFormData({ ...formData, categoriaId: Number(e.target.value) })}
                  >
                    {categorias.map((c) => (
                      <option key={c.categoriaId} value={c.categoriaId}>{c.nombre}</option>
                    ))}
                  </select>
                  <small style={{ color: "#64748b" }}>
                    Solo aparecen las categorías ya sincronizadas desde Catálogo (la copia es asíncrona).{" "}
                    <button type="button" className="btn btn-outline btn-sm" onClick={cargarDatos}>Actualizar</button>
                  </small>
                </div>

                <div className="form-group">
                  <label className="form-label">Prioridad *</label>
                  <select
                    className="form-control"
                    value={formData.prioridad}
                    onChange={(e) => setFormData({ ...formData, prioridad: e.target.value })}
                  >
                    {prioridades.map((p) => (
                      <option key={p.id} value={p.nombre}>{p.nombre} (SLA: {p.tiempoResolucionHoras}h)</option>
                    ))}
                  </select>
                </div>
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.5rem", marginTop: "1.5rem" }}>
                <button type="button" className="btn btn-outline" onClick={() => setShowModal(false)}>Cancelar</button>
                <button type="submit" className="btn btn-primary">Registrar Solicitud</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
