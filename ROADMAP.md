# Roadmap : Brussels Mobility Dashboard

Durée prévue : 4 semaines (du 19 octobre au 16 novembre 2026 environ).

## Phase 0 : Cadrage (19 octobre)
- [x] Choisir le titre et créer le repo public
- [x] Choisir la source de données : STIB (GTFS + API temps réel, licence CC BY 4.0)
- [x] Définir 3 à 4 questions d'analyse (voir README)
- [ ] Installer PostgreSQL, Python, Git, Power BI Desktop (Windows)

## Phase 1 : Données et SQL (semaine 1)
- [x] Schéma en étoile : table de faits + dimensions (date, station/ligne, ...)
- [x] Scripts `CREATE TABLE` (clés primaires, clés étrangères, index)
- [x] Script Python de chargement du GTFS (horaires prévus)
- [x] Chargement : table de staging brute, puis transformation SQL vers les tables finales
- [ ] Script Python de collecte de l'API temps réel (positions des véhicules)
- [ ] Vues SQL d'analyse (agrégations, jointures, fenêtrage, CTE)
- [ ] Automatisation de la collecte quotidienne

**Livrable :** base propre, scripts SQL versionnés, schéma de la base.

## Phase 2 : Power BI (semaine 2, réalisé par moi)
- [ ] Connexion à PostgreSQL en mode Import
- [ ] Vérification du modèle et des relations
- [ ] Mesures DAX
- [ ] 2 à 3 pages : vue d'ensemble, analyse détaillée, tendances
- [ ] Mise en page soignée
- [ ] Publication ("Publish to web", données ouvertes uniquement)

**Livrable :** fichier .pbix, lien public, captures d'écran.

## Phase 3 : Site web (semaine 3)
- [ ] Choix de la stack
- [ ] Pages : accueil avec dashboard intégré, méthodologie, conclusions, à propos
- [ ] Responsive et accessible
- [ ] Déploiement

**Livrable :** site en ligne.

## Phase 4 : Finitions (semaine 4)
- [ ] README complet (contexte, architecture, captures, démo, reproduction)
- [ ] Nettoyage du repo (aucun secret, scripts commentés)
- [ ] Export du schéma SQL et des mesures DAX dans le repo
- [ ] Post LinkedIn
- [ ] Mise à jour du profil LinkedIn (section Projets, compétences)

**Livrable :** projet prêt à être montré.