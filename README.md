[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![tests](https://github.com/brookemahoney/ddev-assistant-ollama/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/brookemahoney/ddev-assistant-ollama/actions/workflows/tests.yml?query=branch%3Amain)
[![last commit](https://img.shields.io/github/last-commit/brookemahoney/ddev-assistant-ollama)](https://github.com/brookemahoney/ddev-assistant-ollama/commits)
[![release](https://img.shields.io/github/v/release/brookemahoney/ddev-assistant-ollama)](https://github.com/brookemahoney/ddev-assistant-ollama/releases/latest)

# DDEV Assistant Ollama

## Overview

This add-on integrates Assistant Ollama into your [DDEV](https://ddev.com/) project.

## Installation

```bash
ddev add-on get brookemahoney/ddev-assistant-ollama
ddev restart
```

After installation, make sure to commit the `.ddev` directory to version control.

## Usage

| Command | Description |
| ------- | ----------- |
| `ddev describe` | View service status and used ports for Assistant Ollama |
| `ddev logs -s assistant-ollama` | Check Assistant Ollama logs |

## Advanced Customization

To change the Docker image:

```bash
ddev dotenv set .ddev/.env.assistant-ollama --assistant-ollama-docker-image="ddev/ddev-utilities:latest"
ddev add-on get brookemahoney/ddev-assistant-ollama
ddev restart
```

Make sure to commit the `.ddev/.env.assistant-ollama` file to version control.

All customization options (use with caution):

| Variable | Flag | Default |
| -------- | ---- | ------- |
| `ASSISTANT_OLLAMA_DOCKER_IMAGE` | `--assistant-ollama-docker-image` | `ddev/ddev-utilities:latest` |

## Credits

**Contributed and maintained by [@brookemahoney](https://github.com/brookemahoney)**
