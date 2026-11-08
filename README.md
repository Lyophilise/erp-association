# ERP Association

Projet personnel (indépendant de Lyophilise & Co) : un ERP réutilisable pour
associations sportives, sur le même principe que `mini-erp-artisans` — une
page unique (`index.html`), aucun build, déployée sur GitHub Pages, connectée
à un projet Supabase (auth + base + RLS).

## Modules

| Module | Statut V1 |
|---|---|
| Licences & effectifs | ✅ fonctionnel |
| Trésorerie | ✅ fonctionnel |
| Encadrants & bénévoles | 🔧 schéma prêt, UI à venir |
| Calendrier, tournois & matériel | 🔧 schéma prêt, UI à venir |
| Communication (convocations, relances) | 🔧 schéma prêt, UI à venir |
| Partenaires & sponsoring | 🔧 schéma prêt, UI à venir |
| Boutique | 🔧 schéma prêt, UI à venir |
| Documents & gouvernance | 🔧 schéma prêt, UI à venir |

Le schéma complet (toutes les tables ci-dessus, multi-association, rôles,
RLS) est déjà appliqué en direct sur le projet Supabase `erp-association`
(`supabase/migrations/0001_init.sql` en documente le contenu), même si l'UI
ne couvre pour l'instant que les deux premiers modules.

## Multi-tenant

Conçu pour plusieurs associations (`organizations`) dès le départ, avec des
rôles par membre (`memberships.role` : président, bureau, trésorier,
secrétaire, coach, bénévole, membre) protégés par RLS — pensé pour être
réutilisé par d'autres clubs plus tard, pas seulement le vôtre.

## Mise en route

`index.html` est déjà connecté au projet Supabase `erp-association`
(`SUPABASE_URL` / `SUPABASE_ANON_KEY` renseignés). Pour démarrer :

1. Créer manuellement la première organisation + le premier membership
   `president` (ou `bureau`) via le SQL editor Supabase — les invitations
   par rôle viendront dans une V2 (comme sur `mini-erp-artisans`).
2. Ouvrir `index.html`, créer un compte (email/mot de passe), se connecter.
3. Déployer sur GitHub Pages (branche principale, racine) une fois le repo
   créé.

## Identité visuelle

Les couleurs actuelles (`index.html`, bloc `:root`) sont un placeholder
neutre. À remplacer par la charte graphique réelle du club une fois fournie
(logo, couleurs, site existant — mentionné : le site du club est sur
WordPress).

## Statut

En cours de construction — voir le fil de conversation pour l'état exact
des décisions en attente (visibilité du repo GitHub, identité visuelle du
club).
