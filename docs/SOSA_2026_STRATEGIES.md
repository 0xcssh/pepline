# SOSA 2026 — les grands points, et la stratégie par type d'app

Digest du rapport RevenueCat *State of Subscription Apps 2026* (115 000 apps,
16 Md$ de revenus, plus d'un milliard de transactions, période de référence
2025 ; PDF dans `docs/`). Tous les chiffres sont des **médianes** sauf mention
« top 25 % » ou « top 10 % ». Écrit pour choisir vite la bonne stratégie
selon l'app qu'on lance.

---

## 1. Les dix points à retenir

1. **Marché à vainqueur dominant.** Médiane de croissance du MRR : +5 % par an.
   Top 25 % : +80 %. Top 10 % : +306 %. Bas de 25 % : −33 %. Il n'y a pas de
   milieu confortable.
2. **Choc d'offre.** 15 000 nouvelles apps à abonnement par mois (2 000 en
   2022), 77 % sur iOS. Les apps lancées depuis 2025 font 3 % des revenus ;
   celles d'avant 2020, 69 %. **La distribution est la barrière, pas le code.**
3. **Paywall dur = 5× la conversion du freemium** (10,7 % contre 2,1 % à J35),
   rétention à un an identique (27 % contre 28 %). Le freemium ne se justifie
   que par le bouche-à-oreille, les effets de réseau ou la marque.
4. **Le jour 0 décide tout.** 80 à 90 % des essais démarrent le jour du
   téléchargement, la moitié des conversions aussi, 55 % des annulations
   d'essais de 3 jours arrivent dans les heures qui suivent. Le « aha » doit
   être immédiat.
5. **Les essais longs convertissent mieux et le marché fait l'inverse.**
   Essai → payant : 25,5 % (≤ 4 j), 37,4 % (5-9 j), 42,5 % (17-32 j). Pourtant
   46,5 % des apps sont à ≤ 4 jours.
6. **Le prix fait la LTV.** Apps chères : 62 $ de LTV an 1 par payeur, apps bon
   marché : 11 $. Conversion aussi meilleure (2,8 % contre 1,4 %). Le coût :
   environ +1 point de remboursements par palier.
7. **Le premier renouvellement est l'inflexion.** Hebdo : 35-54 % au premier,
   68-81 % au deuxième. Annuel : 24-47 % puis 52-70 %. Survivre au premier
   cycle change tout.
8. **Les échecs de facturation sont une fuite silencieuse** : 15 % des
   annulations App Store, 32 % sur Google Play. Période de grâce obligatoire.
9. **Les offres sont rares et mal comprises.** 9,3 % des apps en utilisent.
   Remise standard −50 %. Les top performers n'en dépendent pas (0-10 % des
   nouveaux payeurs), les apps « hobby » si (65-99 %). L'offre payante
   d'introduction (0,99 $ le premier mois) remplace peu à peu l'essai gratuit.
10. **Le framework ne change rien à la médiane.** Flutter 1,8 %, natif 2,0 %,
    React Native 2,5 % de conversion J35 ; rétention annuelle 27-31 % pour
    tous. La variance dans un framework est 10 à 30× l'écart entre eux.
    Choisir selon les fonctions natives dont le produit aura besoin.

## 2. Les benchmarks à connaître par cœur

| Métrique | Médiane | Top 25 % | Où se situer |
|---|---|---|---|
| Téléchargement → essai (J30) | 5-7 % (Business 9,1 %) | 11-16 % | Sous 4 % = problème de paywall ou d'onboarding |
| Essai → payant | 32 % toutes durées | 45-50 % | Dépend surtout de la durée d'essai et du pays |
| Téléchargement → payant (J35) | 2,0 % global, 10,7 % paywall dur | 4,5 % / 20 % | Sous 1 % = bas de tableau |
| Revenu par install J14 / J60 | 0,23 $ / 0,34 $ | 0,48 $+ / 0,66 $+ | Paywall dur : 2,32 $ / 3,09 $ |
| LTV an 1 par payeur | 23 $ global, 32 $ Amérique du Nord | 44 $+ | Sous 10 $ = bas de tableau |
| Rétention an 1 | annuel 28 %, mensuel 8 %, hebdo 1-2 % | annuel 32-59 % | L'hebdo est de la monétisation immédiate, pas de la fidélité |
| Taux de remboursement | 3-4 % | sous 2 % | Au-delà de 9 % = prix ou promesse à revoir |
| Prix | 5,99 $ sem., 9,99 $ mois, 34,80 $ an | 10 $ / 22,70 $ / 90 $ | Les ancres 5 / 10 / 30 sont collantes |
| Revenu mensuel 1 an après lancement | 72 $ | 429 $ (top 10 % : 2 574 $) | 4,6 % des apps atteignent 10 k$/mois en 2 ans |
| Temps pour 1 k$/mois | 58 jours (jeux 32, business 113) | — | Attendre ~100 jours avant de juger |

Géographie : l'Amérique du Nord mène tout (conversion J35 2,6-2,8 %, LTV 32 $,
RPI J60 0,55 $). Europe de l'Ouest juste derrière sur la valeur par payeur
(26 $). Inde et Asie du Sud-Est : prix à 50 % des marchés premium, conversion
à la moitié. **Toujours segmenter par géo avant de comparer à une médiane.**

Stores : conversion J35 2,9 % App Store contre 2,6 % Google Play, RPI J60
2,6× plus haut sur iOS (0,42 $ contre 0,16 $), mais LTV an 1 presque égale
(23,38 $ contre 21,62 $) et conversion d'essai identique (32,5 %).

## 3. Les règles de paywall que les données soutiennent

- **Structure** : deux plans (la norme dans 41-60 % des catégories), prix mis en
  avant (75 % des paywalls), mention « essai gratuit » (54 %), « résiliable à
  tout moment » visible, bouton « Continuer » ou « Essayer gratuitement ».
  Scrollable (59-76 %), texte dense (45-63 %). Multi-étapes en progression.
- **Compte à rebours et barres de progression : moins de 2 % des apps.** Ce
  n'est pas une norme, c'est un signal d'app cheap.
- **Clarté avant persuasion** (Duolingo) : chronologie de l'essai, date du
  prélèvement, procédure de remboursement. Laisser choisir le jour du rappel
  de fin d'essai a augmenté la conversion.
- **Moins d'options** (Tinder) : surfacer le seul bon produit pour l'utilisateur
  plutôt que tous les paliers.
- **Retester par marché** : un paywall long gagnant au Japon (+20 %) a échoué
  aux États-Unis, où le court et percutant gagne.
- **Fréquence** (Mojo) : montrer un paywall une fois par semaine aux gratuits
  à l'ouverture a fait 15 % de revenu en plus sans réaction négative, si le
  gratuit est généreux.
- **Reverse trial** (App Masters) : accès premium temporaire pour ceux qui
  ferment le paywall, sans carte ; freemium de 0,4 % à 4,5 %.
- **Vérifier les renouvellements** (Yousician) avant de déclarer un test gagnant ;
  revérifier les cohortes à 3 et 6 mois.
- **Web** : 41 % des apps du top tier ont du revenu web, 1,3 % des apps hobby.
  Sur le web, vendre le problème avant la solution, et un premier mois très
  remisé bat l'essai gratuit.

## 4. Stratégie par type d'app

Pour chaque catégorie : le profil chiffré du rapport, puis ce qu'il faut
mettre en place. Les montants sont en dollars US, médianes, Amérique du Nord
quand c'est précisé.

### Santé & Fitness (RepLock)

- Profil : la meilleure catégorie du rapport. Conversion J35 2,9 % (top 25 % :
  6,2 %, Amérique du Nord 2,7 %), téléchargement → essai 6,9 % (top 25 % :
  23 %), essai → payant 37,7 % (top 25 % : 51 %), RPI J14 0,48 $ et J60 0,66 $
  (les plus élevés), LTV an 1 35,64 $ (Amérique du Nord 39,15 $, top 25 % des
  apps chères 93 $), rétention annuelle 86 %. **Annuel d'abord** : 54-58 % des
  ventes, 59 % du revenu. Essais de 5-9 jours dans 54 % des cas. Prix de
  référence 9,99 $ mois / 39,94 $ an. 14 % des apps utilisent des offres, le
  taux le plus haut.
- Stratégie : paywall dur avec essai de **7 jours**, deux plans, annuel mis en
  avant à 39,99 $ avec badge d'économie, mensuel à 9,99 $ comme porte
  d'entrée. Le « aha » (première séance, premier bénéfice tangible) dans la
  première session, avant ou juste après le paywall. Offres de rétention au
  mois 12 et de retour pour les expirés : la catégorie y est habituée. Viser
  6 % de conversion J35 et 50 % d'essai → payant pour être dans le top 25 %.
  Prix haut assumé : la LTV passe de 9 $ à 69 $ entre bas et haut de gamme.

### Productivité

- Profil : conversion J35 3,4 % en Amérique du Nord (la plus haute), essai →
  payant 31,7 %, LTV an 1 24,89 $. **72 % des conversions le jour 0**, le
  record. **Mensuel à 66-87 %** des ventes (77 % globalement, 90,7 % du
  revenu). Churn « prix » le plus élevé (44 %), remboursements les plus élevés
  (4,7 %). Réactivation mensuelle exceptionnelle (36 %) : comportement SaaS
  « je reviens quand j'en ai besoin ». Forte présence des apps IA (41 %).
- Stratégie : plan **mensuel** en tête, pas annuel ; l'annuel reste proposé
  pour les 17 % qui le veulent. Tout miser sur le premier jour : onboarding
  qui produit un résultat concret en une session. Campagnes de réactivation
  systématiques (un tiers des churners reviennent). Surveiller les
  remboursements et la sensibilité au prix ; les offres payantes
  d'introduction fonctionnent bien ici.

### Business

- Profil : meilleure conversion téléchargement → essai (9,1 %, top 25 % :
  16,2 %), conversion J35 2,6-2,7 %, essai → payant 37,6 % en Amérique du Nord.
  Le revenu par install **double entre J14 et J60** (0,63 $ → 1,20 $). LTV an 1
  32-35 $, top 25 % 69 $, meilleures apps 120 $+. Écart 7× entre apps chères
  (68,95 $) et bon marché (9,48 $). Renouvellement hebdo de 52 % à 80,5 % au
  troisième cycle. Catégorie la plus lente à 1 k$/mois (113 jours) mais la plus
  dense en valeur. Prix hebdo le plus élevé (6,89 $), annuel 35 $.
- Stratégie : **prix premium sans complexe**, la valeur par payeur suit. Monter
  la densité, pas le volume. Être patient : 100 jours avant de juger. Soigner
  le premier renouvellement, ensuite la fidélité est forte. B2C avec
  monétisation B2B est signalé comme l'opportunité sous-exploitée de 2026.

### Éducation

- Profil : conversion J35 modeste (0,7 à 2,7 % selon géo), essai → payant
  37,4 % en Amérique du Nord, LTV an 1 22,82 $ global, 39,15 $ en Amérique du
  Nord (top percentile 91 $). **Prix annuel le plus élevé de toutes les
  catégories (44,99 $)**, 9,99 $ mensuel. Annuel majoritaire (57-58 %),
  hebdo marginal (5-8 %). Essais de 5-9 jours pour la moitié des apps.
  Conversions moins concentrées le jour 0 (28,5 %), pic à 7 jours.
- Stratégie : annuel premium, essai de 7 jours, et accepter une conversion
  plus lente : la décision se prend à la fin de l'essai, pas à l'install.
  Rappels pendant l'essai qui montrent la progression. Les résultats sont
  très dépendants de l'exécution : l'écart médiane / top est le plus grand.

### Jeux

- Profil : conversion J35 la plus basse (0,7-1,0 %), essai → payant 25 %, LTV
  an 1 11,22 $. **Hebdo à 82 %** des ventes, essais ≤ 4 jours dans 73 % des
  cas, lifetime dans 18 % des paywalls (2-3× les autres). Monétisation
  hybride (abonnement + consommables + lifetime) 4× plus fréquente. Prix bas
  (4,99 $ mois, 24,99 $ an). Le plus rapide à 1 k$/mois (32 jours) et à 10 k$
  (53 jours), meilleur taux d'atteinte de 10 k$ (8,9 %). 40 %+ des conversions
  le jour 0. Les top performers vont jusqu'à −90 % de remise.
- Stratégie : volume et vitesse. Hebdo court avec essai ultra-court, offres
  agressives, lifetime en option, consommables en complément. Le prix fait
  tout : LTV de 9 $ à 69 $ entre paliers. Géographie décisive (hebdo à 74 % en
  Asie-Pacifique). Ne pas comparer aux médianes des autres catégories.

### Médias & Divertissement

- Profil : conversion J35 0,6-2,1 %, essai → payant 32,9 % en Amérique du
  Nord, téléchargement → essai 4,0 % (bas). LTV an 1 23-25 $, écart 10 $ → 57 $
  selon le prix, plus que l'écart géographique. Hebdo important en Europe de
  l'Ouest (35,9 %). Conversions 40-50 % le jour 0 puis **second pic à la
  semaine 6+** (20-27 %). Spread de conversion d'essai le plus large de
  toutes les catégories (11,5 % à 69,5 %). Offres encore présentes dans les
  tiers élevés.
- Stratégie : plan hebdo en Europe, prix premium pour la LTV, et une fenêtre
  d'attribution longue (6 semaines et plus) car une part des payeurs arrive
  tard. Le premier cycle de facturation est le gros événement de churn :
  tout faire pour passer le premier renouvellement.

### Photo & Vidéo

- Profil : conversion J35 la plus élevée en Amérique du Nord (4,1 %), RPI J60
  0,62 $, mais essai → payant le plus bas (22,2 %). LTV an 1 23-26 $, 12 $ → 37 $
  selon le prix. Annuel 50-57 %. **Hebdo le plus montré sur les paywalls
  (33 %)**, essais ≤ 4 jours dans 68 % des cas, paywalls les plus épurés
  (27 % à faible densité de texte). 61 % d'apps IA. Meilleur taux d'atteinte
  de 1 k$/mois (21,4 %). Lifetime fréquent (33 %).
- Stratégie : conversion immédiate à l'install (le besoin est ponctuel),
  hebdo ou annuel selon le marché, paywall visuel et court, lifetime en
  option. Le vrai sujet est la rétention, pas la conversion : le churn IA est
  30 % plus rapide. Prévoir réactivation et offres de retour.

### Social & Lifestyle

- Profil : la seule catégorie où le **sans-essai dépasse le mixte** (43,6 % des
  apps). Hebdo le plus présent dans les ventes (jusqu'à 47 %). Conversion J35
  0,8-3,4 % selon géo, essai → payant 14-31,7 %, LTV an 1 22-25 $. Paywall dur
  36 $ contre freemium 25 $ de LTV. Retention hebdo la plus faible (35 % au
  premier renouvellement). Spread médiane / top 25 % très large.
- Stratégie : vendre direct, souvent sans essai, prix hebdo, paywall dur. La
  géographie et l'exécution comptent plus que le modèle. Mesurer le premier
  renouvellement hebdo comme métrique numéro un.

### Shopping

- Profil : meilleur essai → payant avec le voyage (plancher élevé), conversion
  J35 1,3 % global (3,4 % en Amérique du Nord), LTV an 1 17-25 $, 11 $ → 52 $
  selon le prix. **40 % de paywalls à un seul plan** (2× les autres), essais
  longs les plus fréquents (26 % à 10 jours et plus), annuel 66 % du revenu
  (programmes de fidélité). 70-80 % des conversions le jour 0. Meilleur usage
  des témoignages (16,9 %). Catégorie la plus « pure abonnement » (79,6 %).
- Stratégie : un plan annuel clair, essai long, preuve sociale sur le paywall.
  Capturer l'intention à l'install. Le revenu continue de croître après J14 :
  fenêtre d'attribution longue.

### Voyage

- Profil : **meilleur essai → payant de toutes les catégories (43,5 %, top 25 % :
  62 %)**, mais téléchargement → essai bas (4,1 %) et prix les plus bas partout
  (20 $ an, 4,99 $ mois). Annuel à 66 % des ventes, 74,7 % en Amérique du Nord.
  Essais de 5-9 jours dans 54 % des cas. Paywalls les plus scrollables (76 %)
  et le plus de paywalls à 3 plans et plus (27 %). Churn « pas assez d'usage »
  le plus élevé (saisonnalité), remboursements les plus bas (2,5 %), meilleure
  rétention annuelle à un an (39 %). Longue traîne : 28 % des conversions
  après la semaine 6.
- Stratégie : annuel, essai de 7 jours, et **monter les prix** : la catégorie
  sous-facture alors que ses payeurs convertissent et restent. Accepter la
  saisonnalité ; prévoir des réactivations avant les périodes de voyage.

### Utilitaires

- Profil : conversion J35 1,0-1,6 % (2,7 % en Amérique du Nord), essai →
  payant 32,6 % en Amérique du Nord mais 14,8 % en Inde/ASE, LTV an 1 10 $ →
  51 $ selon le prix, paywall dur 36 $ contre freemium 22 $. Plan mix
  **polarisé** : hebdo dominant hors Occident (42-60 %), annuel en Amérique du
  Nord (46 %) et Europe (47 %). **Remise la plus profonde (−63 %)**. Le
  renouvellement se stabilise vite (hebdo 48,5 % → 78,6 % → 84,9 %).
- Stratégie : paywall dur, plan adapté à la géo (annuel en Occident, hebdo
  ailleurs), prix premium en Occident. Le levier est la prise d'essai dans les
  marchés faibles, pas le paywall. Attention aux remises profondes : elles
  sont la norme de la catégorie mais signent souvent une app bas de tableau.

### Apps IA (transversal)

- Profil : 41 % de revenu par payeur en plus (18,92 $ contre 13,59 $ à 30
  jours), conversion d'essai médiane 8,5 % contre 5,6 %, mais **churn 30 % plus
  rapide**. 60 % de ventes mensuelles (26 % hors IA). ChatGPT a normalisé 20 $
  par mois et l'usage à la carte.
- Stratégie : prix haut et mensuel, et tout investir dans la rétention et la
  réactivation, car la curiosité ne fait pas une habitude. Hybride (crédits,
  usage) pour couvrir les coûts variables.

## 5. Arbre de décision rapide

1. **Le produit a-t-il un bénéfice vécu dans la première session ?** Oui →
   paywall dur avec essai. Non → freemium ou reverse trial, en sachant que la
   conversion sera 5× plus faible.
2. **Le besoin est-il continu (fitness, productivité, business) ou ponctuel
   (photo, voyage, social) ?** Continu → annuel en tête, essai 7 jours.
   Ponctuel → hebdo ou mensuel en tête, essai court ou pas d'essai, et plan
   de réactivation.
3. **Le marché principal est-il l'Amérique du Nord ou l'Europe ?** Oui → prix
   sur l'ancre haute (9,99 $ / 39,99 $) ou au-dessus. Marchés émergents →
   prix locaux à 50 %, hebdo, et travailler la prise d'essai.
4. **Il y a des échecs de paiement ?** Toujours : période de grâce dès le jour 1,
   et sur Android c'est un tiers des annulations.
5. **Un test de paywall gagne ?** Ne rien conclure avant d'avoir vu les
   renouvellements et les remboursements de la cohorte à 3 mois.
6. **Combien de temps avant de juger ?** 100 jours. 17 % des apps font 1 k$ par
   mois, 4,6 % font 10 k$. En dessous de la médiane à 100 jours, c'est la
   distribution ou le jour 0 qu'il faut réparer, rarement le code.
