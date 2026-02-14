# CloudFlow
CloudFlow permet aux entreprises de maitriser et d'automatiser l'ensemble de leur processus DevOps, de la conception initiale au déploiement sur le cloud, en s'affranchissant au maximum de la complexité et des erreurs humaines.

## Objectif
Pipeline CI/CD modulaire pour projets Java Spring Boot (Maven), avec qualité, sécurité et déploiement automatisés.

## Prérequis Backend
- Java 17+
- Maven Wrapper (`mvnw`, `mvnw.cmd`)
- Structure: `backend/pom.xml`, `backend/src/main/java`, `backend/src/test/java`

## Démarrer en local avec un profil dev
- Windows PowerShell:
  - `cd backend`
  - `mvn`
- Linux/macOS:
  - `cd backend`
  - `./mvnw`
- Santé: `http://localhost:8080/management/health`

## Démarrer en local avec un profil prod
- Windows PowerShell:
    - `cd backend`
    - `./mvnw -Pprod`
- Linux/macOS:
    - `cd backend`
    - `mvn -Pprod`

## Tester
- `cd backend && ./mvnw -B -ntp clean test`
- Rapports: `backend/target/surefire-reports/` (JUnit), `backend/target/site/jacoco/` (couverture)

## CI/CD Azure DevOps
- Orchestrateur: `backend/azure-pipelines.yml`
- Templates: `backend/azure/templates/`
- Guide CI: `backend/README/CI-README.md`

## Variables & Secrets
- Variables centralisées: `backend/azure/templates/variables-common.yml`
- Secrets via Variable Group (ex.: `cloudflow`): `SONAR_TOKEN`, `NVD_API_KEY`