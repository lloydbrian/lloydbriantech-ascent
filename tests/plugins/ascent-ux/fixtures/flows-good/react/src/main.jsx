import { createBrowserRouter } from "react-router-dom";
import Teams from "./Teams.jsx";

export const router = createBrowserRouter([
  { path: "/", element: <Teams /> },
  { path: "/teams/:teamId", element: <Teams /> },
  { path: "/teams/:teamId/players", element: <Teams /> },
  { path: "*", element: <p>Not found</p> },
]);
