/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_BASE_URL?: string
  readonly VITE_SHOW_API_OVERRIDE?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
