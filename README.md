# 🍳 Swipe & Cook

**Swipe & Cook** est une application iOS moderne de découverte de recettes inspirée du principe du swipe[cite: 2, 4]. Elle permet aux utilisateurs d'explorer de nouvelles recettes, d'ajuster dynamiquement le nombre de portions, de gérer une liste de favoris et de construire une liste de courses intelligente.

---

## 📱 Aperçu de l'Application (iOS)

L'application iOS est construite nativement en **SwiftUI** avec une architecture **MVVM / Service-Oriented**[cite: 1, 2, 5].

### Fonctionnalités principales
* 🃏 **Interface Swipe Interactive :** Découverte de recettes sous forme de cartes interactives (Swipe à droite/gauche).
* 👥 **Gestion Dynamique des Portions :** Ajustement en temps réel des quantités d'ingrédients selon le nombre de personnes sélectionné[cite: 1, 4].
* 🛒 **Panier & Liste de Courses :** Agrégation automatique des ingrédients des recettes sélectionnées pour faire ses courses facilement.
* ❤️ **Favoris & Synchronisation Cloud :** Sauvegarde des recettes préférées localement (JSON) et synchronisation transparente avec le compte utilisateur via PostgreSQL.
* 🌍 **Support Multilingue :** Application entièrement traduite en **Français** et **Anglais** (Localizable)[cite: 4, 5].
* 🔒 **Authentification :** Inscription, connexion et gestion du profil avec génération de jeton JWT[cite: 1, 4].

---

## 🏗️ Architecture Globale & Infrastructure

Le projet repose sur un modèle client-serveur sécurisé hébergé sur une infrastructure **Proxmox VE** personnelle avec conteneurs LXC et tunnel Cloudflare[cite: 2, 5].
