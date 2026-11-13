import { NavLink } from 'react-router-dom';

const links = [
  ['/', 'Home'],
  ['/motorist', 'Motorist'],
  ['/toll', 'Toll Supervisor'],
  ['/patrol', 'Patrol Dispatch'],
  ['/admin', 'Admin'],
];

export default function Navbar() {
  return (
    <nav className="nav">
      <span className="brand">AutoWays</span>
      {links.map(([to, label]) => (
        <NavLink key={to} to={to} end={to === '/'}
          className={({ isActive }) => (isActive ? 'active' : '')}>
          {label}
        </NavLink>
      ))}
    </nav>
  );
}