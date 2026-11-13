import { useEffect, useState } from 'react';
import api from '../api';
import StatCard from '../components/StatCard';

const labels = {
  motorists: 'Motorists',
  vehicles: 'Vehicles',
  trips: 'Toll Trips',
  unpaid_challans: 'Unpaid Challans',
  open_incidents: 'Open Incidents',
};

export default function Home() {
  const [stats, setStats] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    api.get('/stats').then(r => setStats(r.data))
       .catch(e => setError(e.message));
  }, []);

  return (
    <div className="page">
      <h1>Motorway Overview</h1>
      {error && <p className="error">API error: {error}</p>}
      {!stats && !error && <p>Loading...</p>}
      {stats && (
        <div className="cards">
          {Object.entries(labels).map(([k, l]) =>
            <StatCard key={k} value={stats[k]} label={l} />)}
        </div>
      )}
    </div>
  );
}