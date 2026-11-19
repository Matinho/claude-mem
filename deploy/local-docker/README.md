# claude-mem local-docker

Paquete portable: worker de claude-mem + Ollama en Docker, sin salida a internet.
Cada maquina cliente solo lleva el plugin y apunta al worker con `CLAUDE_MEM_WORKER_URL`.

```
Maquina cliente (Claude Code + plugin)       Docker (este paquete)
  hooks --HTTP 127.0.0.1:37777 ---------->   edge (socat) -> worker -> ollama
                                              red "internal": sin ruta a internet
```

## Que hay

| Servicio | Red | Funcion |
|---|---|---|
| `ollama` | internal | Modelo local que resume las observaciones |
| `worker` | internal | claude-mem worker (SQLite en el volumen `claude-mem-data`) |
| `edge` | internal + edge | Proxy TCP que publica el puerto solo en `127.0.0.1` |
| `model-puller` | egress | Un solo uso: descarga el modelo (perfil `setup`) |

Solo `model-puller` tiene salida a internet, y solo mientras corre el paso de setup.

## Levantar (una vez por maquina)

```bash
cd deploy/local-docker
cp .env.example .env          # completar los dos tokens: openssl rand -hex 32
docker compose --profile setup run --rm model-puller   # descarga el modelo
docker compose up -d --build
```

## Conectar un cliente

En `~/.claude-mem/settings.json` de la maquina cliente:

```json
{
  "CLAUDE_MEM_WORKER_URL": "http://127.0.0.1:37777",
  "CLAUDE_MEM_WORKER_AUTOSTART": "false",
  "CLAUDE_MEM_WORKER_INGEST_TOKEN": "<el mismo del .env>",
  "CLAUDE_MEM_LOCAL_API_TOKEN": "<el mismo del .env>",
  "CLAUDE_MEM_AUTO_UPDATE": "false"
}
```

Y en el entorno del cliente: `DO_NOT_TRACK=1`.
`http` plano solo se acepta en loopback. Para usar el worker desde otra maquina
hace falta HTTPS o un tunel SSH (`ssh -L 37777:127.0.0.1:37777 host`).

## Verificado

Probado con Docker Desktop 29 en Windows 11, modelo `qwen2.5:3b`, CPU:

- Sin token el worker responde 401 (solo `GET /api/health` es publico); con token, 200.
- `worker` y `ollama` no resuelven hosts externos (red `internal`), pero se ven entre si.
- Una observacion sintetica (init + tool `Edit`) se convierte en una observacion util en ~45 s, con el proveedor `OpenAI-compatible`.
- Los datos sobreviven a `docker compose down` + `up` (volumen `claude-mem-data`).

## Decisiones que no son obvias

- **Base `node:22-trixie`**: el binario `tree-sitter-cli` pide glibc >= 2.39 y bookworm trae 2.36.
- **API key de relleno (`ollama`)**: con una URL base propia, claude-mem solo trata como "local" a `localhost` y similares. `http://ollama:11434` no lo es, exige key y, sin ella, cae en silencio a Claude. Ollama ignora la key.
- **`CLAUDE_MEM_QUOTA_FALLBACK_PROVIDER=off`**: por defecto, si el proveedor falla, el trabajo va a Claude. Aca se apaga para no salir de la red aislada.
- **Healthcheck en `/api/health`**: es la unica ruta sin token.

## Limites conocidos

- Chroma esta desactivado (`CLAUDE_MEM_CHROMA_ENABLED=false`): la busqueda es por palabras clave, no semantica.
- El worker no ve los archivos del proyecto del cliente; funciones que leen disco (por ejemplo el File Read Gate) pueden degradarse.
- Un modelo chico (3B) resume peor que Claude. Cambiar `OLLAMA_MODEL` en `.env` y repetir el paso de setup.
- Sin GPU, Ollama corre en CPU y puede ir lento.
- Este paquete NO aisla a Claude Code: la sesion sigue hablando con Anthropic.

## Seguridad

- `.env` tiene tokens: no se commitea.
- El puerto se publica solo en `127.0.0.1`.
- Con `CLAUDE_MEM_LOCAL_API_TOKEN` seteado, el worker exige el token para acceso por red.
