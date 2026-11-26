import { useEffect, useState } from 'react';
import api from '../api';

const tone = (s) =>
  ['Open', 'Completed'].includes(s) ? 'ok'
  : ['Fault', 'Violation'].includes(s) ? 'bad' : 'warn';
const Badge = ({ s }) => <span className={'badge ' + tone(s)}>{s}</span>;
const fmt = (d) => (d ? new Date(d).toLocaleString() : '-');

export default function TollSupervisor() {
  const [plazas, setPlazas] = useState([]);
  const [plazaId, setPlazaId] = useState('');
  const [lanes, setLanes] = useState([]);
  const [trips, setTrips] = useState([]);
  const [msg, setMsg] = useState('');

  useEffect(() => {
    api.get('/toll/plazas').then(r => {
      setPlazas(r.data);
      if (r.data.length) setPlazaId(r.data[0].plaza_id);
    }).catch(e => setMsg(e.message));
  }, []);

  const load = () => {
    if (!plazaId) return;
    api.get(`/toll/plazas/${plazaId}/lanes`).then(r => setLanes(r.data));
    api.get(`/toll/plazas/${plazaId}/trips`).then(r => setTrips(r.data));
  };
  useEffect(() => { load(); }, [plazaId]);

  const setBarrier = async (laneId, status) => {
    try {
      await api.patch(`/toll/lanes/${laneId}/barrier`, { barrier_status: status });
      setMsg('');
      load();
    } catch (e) { setMsg(e.response?.data?.error || e.message); }
  };

  const plaza = plazas.find(p => String(p.plaza_id) === String(plazaId));

  return (
    <div className="page">
      <h1>Toll Supervisor</h1>
      <div className="toolbar">
        <label>Plaza:</label>
        <select value={plazaId} onChange={e => setPlazaId(e.target.value)}>
          {plazas.map(p => (
            <option key={p.plaza_id} value={p.plaza_id}>
              {p.plaza_code} - {p.interchange}
            </option>
          ))}
        </select>
        {plaza && <span>Booths: {plaza.total_booths} | Phone: {plaza.supervisor_phone}</span>}
      </div>
      {msg && <p className="error">{msg}</p>}

      <div className="section">
        <h2>Lanes</h2>
        <table>
          <thead><tr><th>Lane</th><th>Type</th><th>RFID reader</th><th>ANPR unit</th>
            <th>Barrier</th><th>Change</th></tr></thead>
          <tbody>
            {lanes.map(l => (
              <tr key={l.lane_id}>
                <td>{l.lane_number}</td><td>{l.lane_type}</td>
                <td>{l.rfid_reader_serial}</td><td>{l.anpr_unit_serial}</td>
                <td><Badge s={l.barrier_status} /></td>
                <td>
                  {['Open', 'Closed', 'Fault'].map(s => (
                    <button key={s} disabled={l.barrier_status === s}
                      onClick={() => setBarrier(l.lane_id, s)}>{s}</button>
                  ))}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="section">
        <h2>Latest trips at this plaza</h2>
        <table>
          <thead><tr><th>Plate</th><th>Lane</th><th>Entry</th><th>Exit</th>
            <th>Avg speed</th><th>Toll (Rs)</th><th>Status</th></tr></thead>
          <tbody>
            {trips.length === 0 && <tr><td colSpan="7">No trips yet.</td></tr>}
            {trips.map(t => (
              <tr key={t.trip_id}>
                <td>{t.plate_no}</td><td>{t.entry_lane}</td>
                <td>{fmt(t.entry_time)}</td><td>{fmt(t.exit_time)}</td>
                <td>{t.computed_avg_speed_kmh ? t.computed_avg_speed_kmh + ' km/h' : '-'}</td>
                <td>{t.toll_deducted}</td><td><Badge s={t.trip_status} /></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}