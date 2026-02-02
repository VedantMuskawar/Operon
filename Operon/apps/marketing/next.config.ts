import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  transpilePackages: ["@operon/ui"],
  output: "export",
};

export default nextConfig;
