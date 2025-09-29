#!/bin/bash

# Script intelligent d'installation Docker pour Ubuntu
# Version: 2.0
# Description: Automatise l'installation de Docker avec vérifications et gestion d'erreurs

set -e  # Arrête le script en cas d'erreur

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOCKER_KEYRING_PATH="/etc/apt/keyrings/docker.gpg"
DOCKER_LIST_PATH="/etc/apt/sources.list.d/docker.list"

# Fonctions de logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCÈS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[ATTENTION]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERREUR]${NC} $1"
}

# Vérification que le script est exécuté sur Ubuntu
check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Impossible de détecter la distribution Linux"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "pop" ]]; then
        log_error "Ce script est conçu pour Ubuntu et Pop!_OS uniquement"
        log_info "Distribution détectée: $NAME"
        exit 1
    fi
    
    log_success "Distribution compatible détectée: $NAME $VERSION_ID"
}

# Vérification des privilèges root
check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "Le script est exécuté en tant que root"
        read -p "Voulez-vous continuer? (o/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Oo]$ ]]; then
            log_info "Arrêt du script"
            exit 0
        fi
    else
        log_info "Vérification des privilèges sudo..."
        sudo -v
        if [[ $? -ne 0 ]]; then
            log_error "Privilèges sudo insuffisants"
            exit 1
        fi
    fi
}

# Vérification de la connexion internet
check_internet() {
    log_info "Vérification de la connexion internet..."
    
    if ping -q -c 1 -W 1 download.docker.com >/dev/null 2>&1; then
        log_success "Connexion internet disponible"
    else
        log_error "Aucune connexion internet ou impossible d'atteindre download.docker.com"
        log_info "Vérifiez votre connexion et réessayez"
        exit 1
    fi
}

# Nettoyage des anciennes installations
clean_old_installation() {
    log_info "Recherche d'anciennes installations de Docker..."
    
    # Liste des packages à désinstaller
    local packages=("docker.io" "docker-doc" "docker-compose" "docker-compose-v2" "podman-docker" "containerd" "runc")
    local found_packages=()
    
    for pkg in "${packages[@]}"; do
        if dpkg -l | grep -q "$pkg"; then
            found_packages+=("$pkg")
        fi
    done
    
    if [[ ${#found_packages[@]} -gt 0 ]]; then
        log_warning "Packages Docker existants détectés: ${found_packages[*]}"
        read -p "Voulez-vous les désinstaller? (recommandé) [O/n]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            log_info "Désinstallation des anciens packages..."
            sudo apt-get remove -y "${found_packages[@]}" || true
            sudo apt-get autoremove -y || true
            log_success "Anciens packages désinstallés"
        else
            log_info "Conservation des packages existants"
        fi
    else
        log_success "Aucune ancienne installation détectée"
    fi
}

# Mise à jour du système
update_system() {
    log_info "Mise à jour du système..."
    
    sudo apt update
    if sudo apt upgrade -y; then
        log_success "Système mis à jour avec succès"
    else
        log_error "Échec de la mise à jour du système"
        exit 1
    fi
}

# Installation des dépendances
install_dependencies() {
    log_info "Installation des dépendances..."
    
    local deps=("apt-transport-https" "ca-certificates" "curl" "software-properties-common" "gnupg")
    
    if sudo apt install -y "${deps[@]}"; then
        log_success "Dépendances installées avec succès"
    else
        log_error "Échec de l'installation des dépendances"
        exit 1
    fi
}

# Configuration du dépôt Docker
setup_docker_repo() {
    log_info "Configuration du dépôt Docker..."
    
    # Création du répertoire pour les clés
    sudo install -m 0755 -d /etc/apt/keyrings
    
    # Téléchargement et configuration de la clé GPG
    log_info "Téléchargement de la clé GPG Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o "$DOCKER_KEYRING_PATH"
    sudo chmod a+r "$DOCKER_KEYRING_PATH"
    
    # Ajout du dépôt Docker
    log_info "Ajout du dépôt Docker..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=$DOCKER_KEYRING_PATH] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee "$DOCKER_LIST_PATH" > /dev/null
    
    # Mise à jour des packages
    sudo apt update
    
    log_success "Dépôt Docker configuré avec succès"
}

# Installation de Docker
install_docker() {
    log_info "Installation de Docker Engine..."
    
    local docker_packages=("docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin")
    
    if sudo apt install -y "${docker_packages[@]}"; then
        log_success "Docker installé avec succès"
    else
        log_error "Échec de l'installation de Docker"
        log_info "Tentative de résolution des dépendances..."
        sudo apt --fix-broken install -y
        if sudo apt install -y "${docker_packages[@]}"; then
            log_success "Docker installé après résolution des dépendances"
        else
            log_error "Échec définitif de l'installation de Docker"
            exit 1
        fi
    fi
}

# Démarrage et activation du service Docker
start_docker_service() {
    log_info "Démarrage du service Docker..."
    
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Vérification du statut
    if sudo systemctl is-active --quiet docker; then
        log_success "Service Docker démarré et activé"
    else
        log_error "Le service Docker ne fonctionne pas correctement"
        exit 1
    fi
}

# Vérification de l'installation
verify_installation() {
    log_info "Vérification de l'installation..."
    
    # Vérification de la version
    if docker --version >/dev/null 2>&1; then
        log_success "Docker CLI installé: $(docker --version)"
    else
        log_error "Docker CLI non fonctionnel"
        exit 1
    fi
    
    # Choix pour le test hello-world avec validation
    while true; do
        log_info "Souhaitez-vous effectuer le test hello-world ? (oui/non)"
        read -r response
        
        case $response in
            [oO][uU][iI]|[oO]|[yY][eE][sS]|[yY])
                log_info "Test de fonctionnement avec l'image hello-world..."
                if sudo docker run --rm hello-world | grep -q "Hello from Docker"; then
                    log_success "Test hello-world réussi"
                else
                    log_error "Le test hello-world a échoué"
                    exit 1
                fi
                break
                ;;
            [nN][oO][nN]|[nN]|[nN][oO])
                log_info "Test hello-world ignoré"
                break
                ;;
            *)
                log_warning "Réponse non valide. Veuillez répondre par 'oui' ou 'non'"
                ;;
        esac
    done
}

# Configuration des permissions utilisateur
# Configuration des permissions utilisateur (Version améliorée)
setup_user_permissions() {
    log_info "Configuration des permissions utilisateur..."
    
    local current_user=$(whoami)
    
    # Vérifier si l'utilisateur est déjà dans le groupe docker
    if groups "$current_user" | grep -q "\bdocker\b"; then
        log_success "L'utilisateur $current_user est déjà dans le groupe docker."
        log_info "Si les commandes Docker échouent encore, veuillez vous déconnecter et vous reconnecter."
    else
        log_warning "Ajout de l'utilisateur '$current_user' au groupe docker pour éviter l'utilisation de sudo."
        sudo usermod -aG docker "$current_user"
        log_success "Utilisateur $current_user ajouté au groupe docker."
        
        # Option 1: Tenter d'activer les changements de groupe sans déconnexion
        log_info "Activation des nouveaux privilèges groupaux pour la session actuelle..."
        if newgrp docker <<< "exit"; then
            log_success "Privilèges groupaux activés. Vous devriez pouvoir utiliser Docker sans sudo."
        else
            log_warning "La commande 'newgrp' a échoué. Pour une prise d'effet complète, vous devez vous déconnecter et vous reconnecter."
            log_info "En attendant, vous pouvez exécuter manuellement: newgrp docker"
        fi
    fi
    
    # Vérification finale des permissions
    log_info "Vérification des permissions du socket Docker..."
    local socket_perms=$(stat -c "%U:%G" /var/run/docker.sock 2>/dev/null || echo "NOT_FOUND")
    log_info "Permissions du socket Docker: $socket_perms"
}

# Fonction principale
main() {
    echo -e "${BLUE}"
    echo "=========================================="
    echo "  Installation intelligente de Docker    "
    echo "=========================================="
    echo -e "${NC}"
    
    # Séquence d'installation
    check_ubuntu
    check_privileges
    check_internet
    clean_old_installation
    update_system
    install_dependencies
    setup_docker_repo
    install_docker
    start_docker_service
    verify_installation
    setup_user_permissions
    
    echo -e "${GREEN}"
    echo "=========================================="
    echo "    Installation terminée avec succès!    "
    echo "=========================================="
    echo -e "${NC}"
    echo ""
    log_success "Docker est maintenant installé et fonctionnel"
    echo ""
    log_info "Commandes utiles:"
    echo "  docker --version                      # Vérifier la version"
    echo "  docker ps                             # Lister les conteneurs"
    echo "  docker images                         # Lister les images"
    echo "  docker run hello-world               # Tester Docker"
    echo ""
    log_info "Documentation: https://docs.docker.com/"
}

# Point d'entrée du script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi