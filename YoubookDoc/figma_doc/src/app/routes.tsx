import { createBrowserRouter } from "react-router";
import Root from "./layouts/Root";
import SignIn from "./pages/auth/SignIn";
import RegisterClient from "./pages/auth/RegisterClient";
import RegisterCenter from "./pages/auth/RegisterCenter";
import PasswordReset from "./pages/auth/PasswordReset";
import Onboarding from "./pages/auth/Onboarding";
import AdminDashboard from "./pages/admin/AdminDashboard";
import ClienteDetailPage from "./pages/admin/ClienteDetailPage";
import StaffDashboard from "./pages/staff/StaffDashboard";
import ClientDiscovery from "./pages/client/ClientDiscovery";
import ClientDashboard from "./pages/client/ClientDashboard";
import CrossModuleStatesPage from "./pages/CrossModuleStates";
import MCPCodeConnectMapping from "./pages/MCPCodeConnectMapping";
import DevDashboardSelector from "./pages/DevDashboardSelector";
import NotFound from "./pages/NotFound";

export const router = createBrowserRouter([
  {
    path: "/",
    Component: Root,
    children: [
      { index: true, Component: DevDashboardSelector }, // ⚡ Dev: Pagina selezione dashboard
      { path: "signin", Component: SignIn },
      { path: "register", Component: RegisterClient },
      { path: "register-center", Component: RegisterCenter },
      { path: "password-reset", Component: PasswordReset },
      { path: "onboarding", Component: Onboarding },
      { path: "admin/*", Component: AdminDashboard },
      { path: "admin/cliente/:id", Component: ClienteDetailPage },
      { path: "staff/*", Component: StaffDashboard },
      { path: "client", Component: ClientDiscovery },
      { path: "client/dashboard/*", Component: ClientDashboard },
      { path: "cross-module-states", Component: CrossModuleStatesPage },
      { path: "mcp-code-connect", Component: MCPCodeConnectMapping },
      { path: "*", Component: NotFound },
    ],
  },
]);