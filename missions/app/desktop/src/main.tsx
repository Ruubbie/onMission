import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./design/tokens.css";
import "./design/base.css";
import { brand } from "./design/brand";
import App from "./App";
import { installLinkHandler } from "./platform";

document.title = brand.appName;
installLinkHandler();
createRoot(document.getElementById("root")!).render(<StrictMode><App /></StrictMode>);
