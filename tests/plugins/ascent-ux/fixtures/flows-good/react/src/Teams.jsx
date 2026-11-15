import { Link, NavLink, useNavigate } from "react-router-dom";

export default function Teams({ team }) {
  const navigate = useNavigate();
  return (
    <section aria-labelledby="teams-title">
      <h2 id="teams-title">Teams</h2>
      {/* <Link to="/archive">must be ignored</Link> */}
      <NavLink to="/">All teams</NavLink>
      <Link to="/teams/3">Team 3</Link>
      <Link to={`/teams/${team.id}/players`}>Players</Link>
      <Link to={"/teams/7/players"}>Team 7 players</Link>
      <button onClick={() => navigate("/teams/9")}>Open team 9</button>
      <a href="#teams-title">Top of the list</a>
    </section>
  );
}
