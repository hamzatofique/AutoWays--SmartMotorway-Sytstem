import { Routes, Route } from 'react-router-dom';
import Navbar from './components/Navbar';
import Home from './pages/Home';
import MotoristPortal from './pages/MotoristPortal';
import TollSupervisor from './pages/TollSupervisor';
import PatrolDispatch from './pages/PatrolDispatch';
import AdminDashboard from './pages/AdminDashboard';

export default function App() {
  return (
    <>
      <Navbar />
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/motorist" element={<MotoristPortal />} />
        <Route path="/toll" element={<TollSupervisor />} />
        <Route path="/patrol" element={<PatrolDispatch />} />
        <Route path="/admin" element={<AdminDashboard />} />
      </Routes>
    </>
  );
}