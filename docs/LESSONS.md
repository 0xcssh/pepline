# RepLock — leçons et playbook pour la prochaine app

Document personnel, écrit en français, pour réutiliser ce qui a marché sur
RepLock (juillet → octobre 2026) et éviter de repayer les erreurs. Il croise
trois sources : ce qu'on a vécu sur le projet, les chiffres réels de RepLock
(Apple, RevenueCat, TelemetryDeck), et le rapport RevenueCat *State of
Subscription Apps 2026* (SOSA, 115 000 apps, 16 Md$ de revenus — le PDF est
dans `docs/`). Les benchmarks cités sont les médianes SOSA sauf mention.

Lecture rapide : la partie 1 est la méthode, la partie 2 le marché et les
chiffres, la partie 3 la checklist à copier pour la prochaine app.

---

## Partie 1 — Comment on a construit RepLock

### 1.1 Le pipeline sans Mac

La contrainte qui a tout façonné : zéro Mac, zéro Xcode local. Ça a marché, et
c'est reproductible.

- **Projet généré** par XcodeGen depuis `project.yml`. Le `.xcodeproj` n'est
  jamais commité. Ajouter un fichier, une cible, un package SwiftPM : une ligne
  dans le YAML.
- **CI GitHub Actions sur `macos-15`** : tests unitaires dans le simulateur à
  chaque push, build signé (IPA) ou upload TestFlight à la demande
  (`workflow_dispatch` avec un input `export_method`). Le simulateur est choisi
  dynamiquement (`xcrun simctl list`) parce que les images de runner renomment
  les appareils.
- **Signature depuis Windows** : CSR + clé privée générés avec OpenSSL, certificat
  créé sur le portail Apple, `.p12` encodé en base64 dans les secrets GitHub. Un
  certificat de développement pour l'USB, un certificat de distribution pour
  TestFlight et l'App Store, même clé privée.
- **Installation USB** : `pymobiledevice3` sous Python 3.12 (ne compile pas sur
  3.14). Si l'install reste muette alors que `lockdown info` répond : redémarrer
  l'iPhone, pas le PC. Ne jamais lancer deux installs en parallèle.
- **TestFlight** : l'upload se fait directement pendant l'export
  (`destination=upload`), numéro de build = numéro de run Actions, donc
  toujours unique. C'est devenu le chemin principal dès que des testeurs
  externes sont arrivés.
- **Un cycle complet sur appareil coûte 15 minutes.** D'où la règle suivante.

### 1.2 Pousser toute la logique dans un cœur pur et testé

C'est la décision d'architecture la plus rentable du projet.

- La caméra et Vision ne font qu'extraire des signaux (articulations). **Tout
  le comptage vit dans des machines d'état Swift pures** (`RepCounter`,
  `HoldTimer`, `ExerciseEngine`) sans dépendance caméra, donc testables en CI.
- Chaque rapport terrain devient d'abord un test qui reproduit le bug, puis un
  correctif, puis seulement un build. Exemples : les squats rapides du cousin
  (zéro rep) → test sinusoïdal à 150 reps/min à 30 et 15 images/s → correctif
  de la temporisation → CI verte en 10 minutes, sans toucher un téléphone.
- Les seuils de détection sont des constantes nommées avec le *pourquoi* en
  commentaire et la date du rapport terrain. Les impasses sont documentées
  pour ne pas être retentées (angle du coude, largeur d'épaules seule, largeur
  du visage pour les pompes).
- **Règle produit : rappel avant précision.** Une rep fantôme de temps en temps
  ne fait pas désinstaller ; une vraie rep non comptée, si.

### 1.3 Décisions de produit qui ont tenu

- **Économie en banque de minutes** plutôt qu'en chrono : les reps créditent un
  solde, le déblocage le débite, relock silencieux. Simple à expliquer, simple à
  tester (`CreditLedger` pur).
- **Strict absolu** : pas de bouton passer, pas de sortie de secours. C'est le
  positionnement, et le marché le valide (voir 2.3).
- **Screen Time** : deux stratégies de relock en parallèle (fin d'intervalle +
  seuil d'usage), noms d'activité uniques, intervalle commençant dans le passé,
  filet de sécurité au retour au premier plan, et une notification locale à la
  seconde près parce que l'API peut traîner d'une minute. Chaque ligne de cette
  liste est un bug terrain.
- **Compte à rebours de 5 s puis reset du moteur** avant de compter : c'est ce
  qui supprime les reps fantômes dues à la mise en place du téléphone. Rendu
  thread-safe et estampillé par génération après l'audit.
- **Localisation obligatoire dès le départ** : 9 langues via un catalogue
  `.xcstrings` compilé dans toutes les cibles (la carte de blocage aussi affiche
  du texte). Toute chaîne ajoutée part avec ses 8 traductions dans le même
  commit, vérifiées par script.

### 1.4 Design

- Un seul fichier de design system (`Theme.swift`) : navy pour la structure,
  dégradé orange→rose **uniquement** pour les moments de récompense. Ne pas
  diluer le dégradé, c'est ce qui le rend lisible.
- Pas d'emoji, SF Symbols seulement, photos en bichromie navy. Règle de l'auteur :
  « ne jamais avoir l'air cheap ».
- Les pictogrammes dessinés à la main ont été validés sur des planches
  rasterisées **avant** de builder. Ne plus jamais livrer un `Path` à l'aveugle.
- Les captures App Store sont **générées par script** (Pillow) depuis un JSON de
  textes : 9 langues × 6 visuels en une commande, fond bleu texturé, téléphone
  moderne, titre en capitales condensées. Changer un titre = une ligne.

### 1.5 App Store Connect par l'API, pas à la main

Tout ce qui est fastidieux dans ASC a fini en script Python sur un runner
Linux (zéro minute macOS) : statistiques de ventes et d'abonnements, fiche
produit en 12 localisations, captures, période de grâce, création de
l'abonnement mensuel, code promo, capture de review. Chaque script a un mode
« à blanc » et est idempotent. Pièges rencontrés :

- La description d'un abonnement est limitée à 55 caractères.
- Un prix ne peut être posé qu'après la disponibilité par territoire, et
  l'API n'égalise pas les prix : il faut poster une ligne par territoire (174)
  depuis les équivalences du point de prix de base.
- Une nouvelle fiche de version ne reprend ni le texte promotionnel ni les
  nouveautés. L'URL d'assistance est obligatoire par langue.
- Un nom d'app est unique sur tout le store, par langue (« Bloqueador de Apps »
  était pris).
- Un nouvel achat intégré doit être soumis avec une version d'app la première
  fois.
- Le numéro de vendeur n'est pas dans l'API ; il est dans « Paiements et
  rapports financiers ».
- L'URL des notifications serveur (vers RevenueCat) n'est pas dans l'API.
- Les rapports Analytics d'Apple mettent 24 à 48 h à se remplir après la
  première demande.

### 1.6 Le délire GitHub privé / public

- Les minutes macOS coûtent 10× les minutes Linux et le quota privé fond en
  quelques builds. Dépôt **public = minutes illimitées gratuites**.
- Ce qu'on a fait : public pendant le développement intensif, **privé avant la
  soumission**, puis bascule public → run → privé à chaque fois que la
  facturation bloquait. Commande dans CLAUDE.md.
- Conditions pour que ce soit tenable : aucun secret dans le code (clés
  publiques RevenueCat/TelemetryDeck acceptées, tout le reste en secrets
  GitHub ou dans un dossier local hors dépôt), détails personnels nettoyés des
  docs, et conscience que **l'historique reste visible** une fois publié.
- Toujours annuler le run déclenché par le push avant de lancer un build à la
  demande : deux runs macOS en parallèle se gênent et doublent la facture.
- Les workflows Linux (stats, fiche, captures, admin ASC) ne coûtent presque
  rien et restent utilisables même quand les macOS sont bloqués.

### 1.7 App Review, ce qui a été refusé et comment c'est passé

- **3.1.2(c)** : le flux d'achat doit afficher le *titre* de l'abonnement, sa
  durée et son prix, plus la mention de renouvellement automatique. Corrigé en
  affichant `product.displayName` sur la carte d'offre et une ligne complète en
  bas du paywall.
- **2.1(a)** : un bouton qui ne fait rien quand le produit n'est pas chargé est
  un rejet. Toujours réessayer puis afficher une alerte.
- Le paywall dur (sans croix) passe en review ; le paywall de promotion est
  fermable.
- Notes pour le reviewer : préciser qu'il faut un vrai iPhone (Screen Time et
  caméra ne marchent pas en simulateur).
- Le label de confidentialité doit dire la même chose que la description. Le
  jour où on a ajouté TelemetryDeck, la description disait encore « aucune
  donnée collectée » : corrigé avant soumission.

### 1.8 Mesurer avant de décider

On a tourné trois mois à l'aveugle avec seulement les ventes Apple. Le jour où
TelemetryDeck a été posé (une demi-journée, signaux anonymes, pas d'ATT), la
première semaine de données a renversé deux intuitions :

- L'onboarding de 18 écrans ne perdait **personne** (23 utilisateurs sur chaque
  écran). Inutile de le raccourcir.
- La fuite était sur la **feuille de paiement Apple** : 13 personnes sur 23
  reculaient devant « 39,99 $ par an ». Ça a donné le plan mensuel.

Règles retenues :

- Un seul fichier `Analytics.swift` avec le vocabulaire des événements ; le SDK
  n'est référencé nulle part ailleurs.
- Instrumenter la boucle complète dès la v1 : chaque écran d'onboarding,
  résultat de chaque permission (avec le code d'erreur), paywall affiché,
  achat démarré et résultat, séance démarrée / terminée / annulée avec la
  phase et le temps « corps non détecté », déblocage.
- Croiser trois sources : Apple (ventes, page produit, suppressions),
  RevenueCat (statut exact par abonné, `auto_renewal_status`,
  `pending_payment`), TelemetryDeck (comportement). Filtrer `environment ==
  production` dans RevenueCat, sinon les testeurs sandbox gonflent tout.
- Ne jamais coller une clé d'API dans un chat. Dossier local `replock-signing`
  ou secrets GitHub, et rotation si ça arrive quand même.
- Interface RevenueCat : la ligne « Trial Converted » avec un tiret en revenu
  est la transaction d'essai elle-même, pas un échec de paiement. Juger sur
  l'API.

---

## Partie 2 — Le marché, et où RepLock se situe

### 2.1 Les chiffres de RepLock (juillet → mi-octobre 2026)

| Métrique | RepLock | Médiane SOSA Health & Fitness | Lecture |
|---|---|---|---|
| Impressions → fiche produit | 4 % | — | Icône et sous-titre à travailler |
| Fiche → téléchargement | 26 % | — | Correct |
| Téléchargement → essai | 8 à 15 % | 6,9 % (top 25 % : 23 %) | Dans la norme |
| Essai → payant (3 jours) | 24 % | 25,5 % pour ≤ 4 jours, 37,7 % toutes durées | Normal pour un essai court |
| Téléchargement → payant J35 | ~2 % | 2,9 % (paywall dur : 10,7 %) | Sous la norme du paywall dur |
| Retour le lendemain | 4 % des installs | — | Le vrai problème |
| Annulations d'essai le jour même | 6 sur 20 | 55 % des annulations à 3 jours arrivent le jour 0 | Normal, mais évitable |
| Conversions bloquées en échec de paiement | 2 sur 8 | 15 % des annulations App Store sont des échecs de facturation | Période de grâce indispensable |
| Prix annuel | 39,99 $ | 39,94 $ (Health & Fitness) | Pile sur l'ancre |

La leçon globale : la conversion de RepLock n'est pas mauvaise pour son
modèle, c'est la **rétention au-delà du jour 0** qui plombe tout, et c'est
exactement ce que le rapport décrit comme la bataille de 2026.

### 2.2 Ce que SOSA 2026 dit du marché

- **Offre en explosion** : 15 000 nouvelles apps à abonnement par mois (2 000 en
  2022), 77 % sur iOS. Les apps lancées en 2025 ou après ne font que 3 % des
  revenus ; celles d'avant 2020 en font 69 %. La distribution, pas le code,
  est la barrière.
- **Marché à vainqueur dominant** : le top 25 % croît de 80 % par an, le bas de
  25 % décroît de 33 %. Médiane : +5 %.
- **Health & Fitness est une bonne catégorie** : meilleure conversion
  téléchargement → payant (2,9 %), meilleur revenu par install à J14 (0,48 $) et
  J60 (0,66 $), meilleure LTV an 1 par payeur (35,64 $), rétention annuelle
  86 %. Nord-Amérique devant partout. C'est là que sont 75 % des installs de
  RepLock : garder l'anglais en priorité.
- **Seulement 4,6 % des apps atteignent 10 k$ par mois** en deux ans, 17 % en
  atteignent 1 k$. Il faut environ 100 jours pour savoir si une app a une
  chance d'être un top performer.
- **Framework** : Flutter, natif et React Native monétisent pareil à la médiane
  (conversion 1,8 / 2,0 / 2,5 %, rétention annuelle 27 à 31 % pour tous). La
  variance **à l'intérieur** d'un framework est 10 à 30× plus grande que
  l'écart entre frameworks. Le témoignage HabitKit : parti en Flutter, obligé
  de maintenir trois bases de code dès que les utilisateurs ont voulu des
  widgets et la synchro iCloud, revenu passé à 75/25 iOS ; l'app suivante a été
  faite en SwiftUI natif. Pour RepLock, le natif était de toute façon imposé
  par Screen Time et Vision.

### 2.3 Paywall et accès

- **Paywall dur : 10,7 % de conversion J35 contre 2,1 % en freemium**, cinq fois
  plus, avec un plancher à 4,2 % et un top 10 % à 38,7 %. La rétention à un an
  est identique (27 % contre 28 %). Le choix du paywall dur de RepLock est le
  bon ; l'écart avec 10,7 % montre la marge.
- **Le jour 0 décide tout** : 80 à 90 % des essais démarrent le jour du
  téléchargement, la moitié des conversions aussi, et 55 % des annulations
  d'essais de 3 jours arrivent dans les heures qui suivent. Un utilisateur qui
  ne voit pas la valeur à la première session ne revient pas la chercher.
- **Le paywall médian est simple** : deux plans (60 % en Health & Fitness, la
  norme la plus élevée), prix mis en avant (75 %), mention « essai gratuit »
  (54 %), « résiliable à tout moment » bien visible, bouton « Continuer ».
  Compte à rebours et barres de progression : quasi inexistants. Scrollable
  dans 70 % des cas. Le multi-étapes (fonctions, puis conditions d'essai, puis
  prix) est la tendance, et c'est ce que fait RepLock.
- **Clarté avant persuasion** (Duolingo) : montrer la chronologie exacte de
  l'essai, la date du prélèvement et comment se rembourser convertit mieux que
  vendre plus fort. Laisser choisir le jour du rappel de fin d'essai a augmenté
  la conversion.
- **Moins d'options, pas plus** (Tinder) : la surcharge de choix tue la
  conversion. Deux plans, un mis en avant.
- **Un paywall gagnant au Japon a échoué aux États-Unis** : long et dense là-bas,
  court et percutant ici. Retester par marché.

### 2.4 Essais, prix, plans

- **Les essais longs convertissent mieux** : 25,5 % à ≤ 4 jours, 37,4 % à 5-9
  jours, 42,5 % à 17-32 jours. Pourtant le marché raccourcit (46,5 % d'essais
  ≤ 4 jours). Health & Fitness préfère 5-9 jours (54 %). **Le 3 jours de RepLock
  est en dessous de la norme de sa catégorie** ; 7 jours est la prochaine chose
  à tester, en gardant la date de prélèvement visible.
- **Prix** : l'architecture dominante est 4,99-6,99 $ semaine, 7,99-9,99 $ mois,
  29,99-39,99 $ an. Health & Fitness : 9,99 $ mois, 39,94 $ an. Les apps plus
  chères convertissent mieux (2,8 % contre 1,4 % pour les moins chères) et
  valent 6× plus par payeur à un an (62 $ contre 11 $), au prix d'un peu plus de
  remboursements (+1 point par palier). Leçon Lose It : un prix de base plus
  haut laisse la place aux remises et finance l'acquisition.
- **Mix de plans** : Health & Fitness est à 68 % annuel en volume et 59 % en
  revenu. Les paywalls de la catégorie montrent l'annuel dans 44 % des cas, le
  plus haut taux. Le mensuel ajouté sur RepLock sert de porte d'entrée, pas de
  plan principal.
- **Rétention par durée** : à un an, annuel 20-40 % retenu, mensuel 6-14 %,
  hebdo 1-2 %. Les mensuels se réactivent à 20 %, les annuels à 5 %. Le premier
  renouvellement est le point d'inflexion : passer le premier cycle change tout
  (renouvellement 2 et 3 à 70-80 %).
- **Offres** : seulement 9,3 % des apps en utilisent (Health & Fitness 14 %, le
  plus). Remise médiane -50 %. Les top performers n'en dépendent presque pas
  (0-10 % des nouveaux payeurs), les apps « hobby » si (65-99 %). Les offres
  payantes d'introduction (0,99 $ le premier mois) remplacent de plus en plus
  l'essai gratuit : engagement, moins d'abus, meilleur cash.
- **Reverse trial** (App Masters) : donner l'accès premium temporairement à
  ceux qui ferment le paywall, sans carte ; la perte fait plus peur que le gain
  n'attire. 0,4 % → 4,5 % en freemium.

### 2.5 Rétention et facturation

- **Motifs de churn** : prix (25-45 %) et pas assez d'usage (26-40 %) ; les
  problèmes techniques sont marginaux (3-7 %).
- **Annulations d'annuels** : 35 % au mois 1, puis un pic au mois 12 avant le
  renouvellement. Les trois abonnés RepLock qui ont déjà coupé le renouvellement
  sont dans ce schéma ; la promo de rétention doit les attraper au mois 12.
- **Échecs de facturation** : 15 % des annulations App Store, 32 % sur Google
  Play. La **période de grâce** est le levier le moins cher du rapport. Activée
  sur RepLock le 14 octobre.
- **Remboursements** : 3-4 % médian, plus haut quand le prix monte.
- **Ne pas fêter une hausse de conversion avant d'avoir vérifié les
  renouvellements** (Yousician) : un paywall « gagnant » peut être négatif net
  via annulations et remboursements. Revérifier les cohortes gagnantes à 3 et 6
  mois.

---

## Partie 3 — Checklist pour la prochaine app

### Avant d'écrire une ligne

1. Choisir le framework pour les **fonctions natives** dont le produit aura
   besoin, pas pour la monétisation : les trois monétisent pareil. Screen Time,
   Vision, widgets, iCloud → natif. App de contenu multi-plateforme → Flutter
   reste défendable, en sachant qu'un jour il y aura du Swift à côté.
2. Demander les entitlements à délai (Family Controls distribution) **le jour 1**.
3. Mettre en place le pipeline CI avant le produit : XcodeGen, tests sur
   simulateur, build signé, TestFlight. Un cycle qui marche à vide.
4. Décider ce qui va dans un cœur pur testé. Tout ce qui est logique métier,
   détection, économie, règles.
5. Catalogue de localisation et script de vérification dès le premier écran.
6. `Analytics.swift` avec les événements de la boucle complète, et un label de
   confidentialité cohérent.

### Monétisation (benchmarks SOSA à viser)

7. Paywall dur avec essai, multi-étapes, deux plans, prix en évidence,
   « résiliable à tout moment », chronologie de l'essai et date de
   prélèvement visibles, titre et prix de l'abonnement dans le flux d'achat.
8. Essai de **7 jours** en Health & Fitness (5-9 jours = sweet spot), pas 3.
   Garder 3 jours seulement si la valeur est vécue dans l'heure.
9. Prix sur l'ancre de la catégorie (9,99 $ / 39,99 $), jamais en dessous.
   Mensuel comme porte d'entrée, annuel mis en avant avec le badge d'économie.
10. Période de grâce activée dès la création de l'abonnement. Notifications
    serveur vers RevenueCat configurées le même jour. Code promo de rétention
    créé avant de coder le bouton qui y mène.
11. Prévoir une offre de rétention au mois 12 pour les annuels et une offre de
    retour pour les expirés.

### Activation (le jour 0)

12. Le premier « aha » doit arriver **avant** le paywall ou dans les minutes qui
    suivent l'essai. Pour RepLock : bloquer une app, faire 5 reps, voir
    Instagram s'ouvrir. Ne jamais laisser un utilisateur arriver au paywall
    sans avoir rien configuré.
13. Un cadeau de bienvenue assez petit pour forcer la première action (15 min,
    pas 60).
14. Relances à +3 h et +24 h tant que la première action n'a pas eu lieu, puis
    silence.
15. Demande d'avis au premier retour (deuxième jour distinct), jamais à la
    première séance.

### Fiche App Store

16. Captures générées par script, 9 langues, fond qui tranche dans la
    recherche (le bleu vif a été préféré au navy sombre), première capture =
    le bénéfice, pas la fonctionnalité.
17. Mots-clés sans doublon avec le titre, variantes en-GB / en-AU / en-CA pour
    doubler l'indexation anglophone.
18. Description, label de confidentialité et paywall qui racontent la même
    histoire.
19. Vidéo de prévisualisation quand le produit est visuel (encore à faire sur
    RepLock).

### Exploitation

20. Workflows Linux pour tout ce qui est ASC : stats, fiche, captures, admin.
    Mode à blanc d'abord, toujours.
21. Rapport hebdomadaire croisant Apple + RevenueCat + TelemetryDeck ; décider
    sur des cohortes, pas sur des intuitions ; revérifier à 3 et 6 mois.
22. Privé/public GitHub selon le besoin de minutes macOS, privé avant toute
    soumission, jamais de secret dans l'historique.
23. Laisser 100 jours à une app avant de juger si elle peut devenir un top
    performer ; seules 4,6 % atteignent 10 k$ par mois, et elles ressemblent
    toutes à ça : paywall dur, prix sur l'ancre, jour 0 soigné, rétention
    mesurée.
