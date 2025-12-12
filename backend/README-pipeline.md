# CloudFlow Backend — CI/CD Azure Pipelines (Guide d'architecture et d'exploitation)

Ce document explique clairement au lead ce qui a été mis en place pour la CI/CD du backend CloudFlow (Java + Spring Boot + Maven) sur Azure Pipelines, pourquoi ces choix, ce que chaque stage apporte, et ce qu'il reste à faire pour une chaîne complète, professionnelle et industrialisable.

## 1) Contexte du projet et choix techniques

- Projet: Backend généré avec JHipster 8.x (Java 17, Spring Boot), structure standard, intégration out-of-the-box de tests, qualité et Docker.
- Pourquoi ce projet: 
  - JHipster fournit une base solide, maintenable et standardisée (Spring Boot/Java), idéale pour démontrer des pratiques CI/CD entreprises.
  - Générateurs JHipster CI/CD permettent d'accélérer la mise en place, que nous avons durcie et étendue pour répondre à des exigences DevSecOps modernes.
- Pourquoi JHipster:
  - Convention over configuration: arborescence, dépendances, plugins déjà câblés (Surefire, Failsafe, JaCoCo, Sonar).
  - Productivité: scaffolding rapide, scripts npm utiles, profils dev/prod, docker-compose.
  - Compatibilité enterprise: Maven + Spring Boot + Docker, facilement intégrables à Azure DevOps.

## 2) Vue d'ensemble du pipeline Azure (CI)

La pipeline est organisée en stages indépendants, reproductibles et sécurisés, avec caches, gates de qualité, tests, scans sécurité et publication.

Résumé valeur ajoutée par stage:
- Triggers & filters: réduit les coûts et les exécutions inutiles (branches et chemins ciblés).
- Pinning & setup: builds déterministes via versions figées de JDK/Node.
- Caches de build: accélère fortement les runs répétés (Maven repo, Maven wrapper, npm).
- Priming des dépendances: "fail fast" réseau et remplissage des caches pour stabiliser le reste.
- Gates de formatage/qualité: bloque tôt le code non conforme (Spotless, Checkstyle, Prettier).
- Tests unitaires & rapports: feedback rapide avec publication JUnit + JaCoCo.
- Sonar + Quality Gate: garde-fou qualité bloquant sur main.
- Tests d’intégration: validation de l’app avec env éphémères (option Docker Compose PostgreSQL).
- Scans sécurité SAST/DAST: posture "secure-by-design" avec seuils et politiques adaptées.
- Secret scanning: détection précoce de fuites (Gitleaks) et gate sur main.
- Publication Azure Artifacts: déploiement Maven maîtrisé et traçable.
- Artefacts pipeline: conservation des rapports pour triage et audits.

## 3) Détails par stage et jobs (avec la valeur ajoutée)

### Stage 1 — Triggers & Filters
- Branches: main, develop.
- Paths: ciblage backend (pom.xml, src/**) pour éviter de builder le front inutilement.
- PR: autoCancel, filtration des chemins.
- Valeur: Coûts réduits, CI focalisée sur les changements pertinents.

### Stage 2+3 — Caches + Quality gates
- Jobs: fast_checks.
- Pin JDK/Node dans le job (VM neuve par job).
- Caches: `~/.m2/repository`, `~/.m2/wrapper`, `~/.npm` avec clés basées sur `pom.xml` et `package-lock.json`.
- Priming: `./mvnw dependency:go-offline` et `npm ci`.
- Gates: `spotless:check`, `checkstyle:check`, `prettier --check`.
- Valeur: Build rapide et propre; on s'arrête avant d'investir dans des tests si le code n'est pas conforme.

### Stage 4 — Tests unitaires & rapports
- Job: run_unit_tests.
- Exécute Surefire (`mvn test`), publie JUnit et JaCoCo.
- Artefacts: `surefire-reports`, `jacoco-site`.
- Valeur: Feedback sûr sur la stabilité du code, métriques de couverture disponibles.

### Stage 5 — SonarCloud (Quality Gate)
- Job: sonar_analysis.
- Compile sans tests, réutilise rapports, lance Sonar Maven.
- Gate: script de polling sur Quality Gate, blocage sur main si FAIL.
- Valeur: Garantit que seul du code acceptable arrive sur main (bugs, vulnérabilités, duplications, dette).

### Stage 6 — Tests d’intégration (éphémères)
- Job: itests.
- Option Docker Compose PostgreSQL; exécute Failsafe `verify` (IT), publie rapports et JaCoCo-IT.
- Teardown Compose.
- Valeur: Validation de l’app contre une base réelle; couverture IT distincte pour visibilité.

### Stage 7 — Security scans (SAST & DAST)
- Job: sast_depcheck_docker: OWASP Dependency-Check via Maven (formats JSON/SARIF), seuil CVSS ≥ 7 bloquant sur main.
- Job: dast_zap: démarrage backend en local, scan ZAP baseline en conteneur; rapport HTML publié; exécuté sur main.
- Valeur: Détection précoce vulnérabilités de dépendances et endpoints; politique adaptée aux budgets étudiants.

### Stage 8 — Secret scan
- Job: gitleaks.
- Rapports JSON/SARIF, gate de politique (bloquant sur main si fuite).
- Valeur: Confiance accrue, conformité de base, prévention de l’exfiltration involontaire.

### Stage 9 — Publish Maven (Azure Artifacts)
- Job: maven_deploy.
- Auth via `MavenAuthenticate@0` qui génère un `settings.xml` temporaire; caches Maven; `mvn clean deploy` avec `--settings` et `-DaltDeploymentRepository`.
- Valeur: Publication contrôlée, reproductible et traçable des livrables Maven sur le feed.

## 4) Focus technique: Stage Publish Maven (éviter "settings missing")

Ce qui se passe:
- `MavenAuthenticate@0` crée un fichier `settings.xml` avec les credentials du feed et expose son chemin via la variable de sortie `MAVEN_SETTINGS_PATH`.
- Les étapes suivantes doivent recevoir `MAVEN_SETTINGS_PATH` via `env` et la commande Maven doit utiliser `--settings "$MAVEN_SETTINGS_PATH"`.

## 5) Sécurité, compliance et coûts (étudiant)

- Outils coût: nous privilégions des outils open-source (Dependency-Check, ZAP, Gitleaks) et SonarCloud avec quotas gratuits.
- Compliance: gates Sonar et politiques de secrets; logs et artefacts conservés pour audits.
- Sécurité: pinning des outils, tokens secrets via variables de groupe (Key Vault possible), scans shift-left, blocages sur main.

## 6) Ce qu'il reste à faire pour une CI/CD complète et industrialisable

Courts termes (faible risque):
- Approvals/Environments: ajouter un stage "Gates de compliance" avec approbation manuelle avant publication (Azure Environments).
- Docker Build & Push: stage dédié pour construire l'image backend et la pousser vers ACR (ou registry gratuit) avec tags basés sur `Build.BuildId`.

Moyen terme (structurant):
- Key Vault: externaliser secrets (SONAR_TOKEN, NVD_API_KEY) via Azure Key Vault + `AzureKeyVault@2`.
- Templates YAML: factoriser pinning/caches/priming en templates réutilisables.
- Quality profiles: durcir Checkstyle/Spotless/Prettier et règles Sonar (security hotspots).

Long terme (industrialisation):
- Multi-branch policies: stratégies différentes (feature vs develop vs main).
- Release automation: tagging, changelog, publication GitHub Releases / Azure Artifacts promotion.
- Observabilité: intégrer logs et alertes (Azure Monitor/Log Analytics) sur échecs répétés ou dégradations de performance.
- Scalabilité: pool d’agents privés cache-chaud si temps de build doit chuter fortement.
