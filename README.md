# Automated Docker Installation Script

This script automates the installation of Docker on Linux-based systems (such as Ubuntu, Debian, CentOS, etc.). It is designed to simplify the process, ensuring you have Docker up and running with minimal input. The script will automatically download the latest version of Docker, configure necessary settings, and install Docker Engine & Docker Compose.

## Features

- Automates the Docker installation process
- Installs the latest stable version of Docker
- Configures Docker to start on boot
- Installs Docker Compose (if needed)
- Supports most Linux distributions

## Prerequisites

- A fresh installation of a supported Linux distribution
- A user with `sudo` privileges
- Internet connection (to download Docker packages)

## Supported Distributions

- Ubuntu/Debian (most versions)
- CentOS/RHEL
- Fedora

## Installation

To get started, simply follow the steps below.

### 1. Clone the repository

```bash
git clone https://github.com/yourusername/automated-docker-install.git
cd automated-docker-install
