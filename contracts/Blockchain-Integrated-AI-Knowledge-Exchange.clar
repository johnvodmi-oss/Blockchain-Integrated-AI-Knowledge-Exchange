;; Blockchain-Integrated AI Knowledge Exchange
;; A decentralized platform for sharing AI knowledge, models, datasets, and insights with incentivized contributions
;; Version: 1.0.0
;; Compatible with: Clarinet 3.x

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_KNOWLEDGE_NOT_FOUND (err u404))
(define-constant ERR_INVALID_PARAMETERS (err u400))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))
(define-constant ERR_ALREADY_VOTED (err u409))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u407))
(define-constant ERR_CONTENT_UNAVAILABLE (err u408))
(define-constant ERR_ACCESS_DENIED (err u403))

;; Knowledge Types
(define-constant TYPE_AI_MODEL u1)
(define-constant TYPE_DATASET u2)
(define-constant TYPE_RESEARCH_PAPER u3)
(define-constant TYPE_CODE_SNIPPET u4)
(define-constant TYPE_TUTORIAL u5)
(define-constant TYPE_ALGORITHM u6)
(define-constant TYPE_BEST_PRACTICE u7)

;; Knowledge Categories
(define-constant CATEGORY_MACHINE_LEARNING u1)
(define-constant CATEGORY_DEEP_LEARNING u2)
(define-constant CATEGORY_NLP u3)
(define-constant CATEGORY_COMPUTER_VISION u4)
(define-constant CATEGORY_ROBOTICS u5)
(define-constant CATEGORY_DATA_SCIENCE u6)
(define-constant CATEGORY_AI_ETHICS u7)
(define-constant CATEGORY_GENERAL_AI u8)

;; Access Levels
(define-constant ACCESS_PUBLIC u1)
(define-constant ACCESS_PREMIUM u2)
(define-constant ACCESS_EXCLUSIVE u3)

;; Data Variables
(define-data-var knowledge-counter uint u0)
(define-data-var user-counter uint u0)
(define-data-var platform-fee-percentage uint u10) ;; 10% platform fee
(define-data-var min-contribution-price uint u5000) ;; Minimum 5,000 microSTX
(define-data-var reputation-threshold-premium uint u100) ;; Minimum reputation for premium content
(define-data-var knowledge-reward-multiplier uint u150) ;; 150% reward for high-quality content
(define-data-var ai-verification-enabled bool true) ;; Enable AI content verification

;; Data Maps

;; Knowledge Base Storage
(define-map knowledge-base
    { knowledge-id: uint }
    {
        contributor: principal,
        title: (string-ascii 128),
        description: (string-ascii 1024),
        knowledge-type: uint,
        category: uint,
        access-level: uint,
        price: uint,
        quality-score: uint,
        download-count: uint,
        total-earnings: uint,
        ipfs-hash: (string-ascii 64), ;; IPFS hash for content storage
        ai-verified: bool,
        created-at: uint,
        updated-at: uint,
        tags: (string-ascii 256)
    }
)

;; User Profiles
(define-map user-profiles
    { user: principal }
    {
        username: (string-ascii 32),
        bio: (string-ascii 512),
        expertise-areas: (string-ascii 256),
        reputation-score: uint,
        total-contributions: uint,
        total-downloads: uint,
        total-earnings: uint,
        premium-member: bool,
        ai-researcher-verified: bool,
        joined-at: uint,
        last-active: uint
    }
)

;; Knowledge Votes/Reviews
(define-map knowledge-votes
    { knowledge-id: uint, voter: principal }
    {
        vote-score: uint, ;; 1-5 star rating
        review-text: (string-ascii 512),
        helpfulness-votes: uint,
        voted-at: uint
    }
)

;; Knowledge Access Records
(define-map knowledge-access
    { knowledge-id: uint, user: principal }
    {
        access-granted-at: uint,
        payment-amount: uint,
        access-type: uint, ;; 1: purchased, 2: earned, 3: gifted
        expires-at: (optional uint)
    }
)

;; AI Model Registry (special tracking for AI models)
(define-map ai-model-registry
    { knowledge-id: uint }
    {
        model-type: (string-ascii 64), ;; e.g., "transformer", "cnn", "rnn"
        framework: (string-ascii 32), ;; e.g., "tensorflow", "pytorch"
        version: (string-ascii 16),
        performance-metrics: (string-ascii 256),
        training-data-info: (string-ascii 512),
        computational-requirements: (string-ascii 256),
        license-type: (string-ascii 32)
    }
)

;; Knowledge Collections/Playlists
(define-map knowledge-collections
    { collection-id: uint, owner: principal }
    {
        collection-name: (string-ascii 64),
        description: (string-ascii 512),
        knowledge-ids: (list 20 uint),
        public: bool,
        created-at: uint
    }
)

;; Platform Analytics
(define-map daily-stats
    { date: uint }
    {
        new-knowledge-items: uint,
        total-downloads: uint,
        active-users: uint,
        revenue-generated: uint
    }
)

;; Public Functions

;; Create user profile
(define-public (create-user-profile
    (username (string-ascii 32))
    (bio (string-ascii 512))
    (expertise-areas (string-ascii 256)))
    (begin
        (asserts! (> (len username) u0) ERR_INVALID_PARAMETERS)
        (asserts! (> (len expertise-areas) u0) ERR_INVALID_PARAMETERS)
        
        (map-set user-profiles { user: tx-sender }
            {
                username: username,
                bio: bio,
                expertise-areas: expertise-areas,
                reputation-score: u50, ;; Starting reputation
                total-contributions: u0,
                total-downloads: u0,
                total-earnings: u0,
                premium-member: false,
                ai-researcher-verified: false,
                joined-at: burn-block-height,
                last-active: burn-block-height
            }
        )
        
        (var-set user-counter (+ (var-get user-counter) u1))
        (ok true)
    )
)

;; Share knowledge/contribute content
(define-public (share-knowledge
    (title (string-ascii 128))
    (description (string-ascii 1024))
    (knowledge-type uint)
    (category uint)
    (access-level uint)
    (price uint)
    (ipfs-hash (string-ascii 64))
    (tags (string-ascii 256)))
    (let 
        (
            (user-profile (unwrap! (map-get? user-profiles { user: tx-sender }) ERR_UNAUTHORIZED))
            (new-knowledge-id (+ (var-get knowledge-counter) u1))
        )
        (asserts! (> (len title) u0) ERR_INVALID_PARAMETERS)
        (asserts! (> (len description) u0) ERR_INVALID_PARAMETERS)
        (asserts! (and (>= knowledge-type u1) (<= knowledge-type u7)) ERR_INVALID_PARAMETERS)
        (asserts! (and (>= category u1) (<= category u8)) ERR_INVALID_PARAMETERS)
        (asserts! (and (>= access-level u1) (<= access-level u3)) ERR_INVALID_PARAMETERS)
        (asserts! (> (len ipfs-hash) u0) ERR_INVALID_PARAMETERS)
        
        ;; Validate price based on access level
        (asserts! (or (and (is-eq access-level ACCESS_PUBLIC) (is-eq price u0))
                     (and (> access-level ACCESS_PUBLIC) (>= price (var-get min-contribution-price)))) ERR_INVALID_PARAMETERS)
        
        ;; Check reputation for premium content
        (asserts! (or (not (is-eq access-level ACCESS_EXCLUSIVE)) 
                     (>= (get reputation-score user-profile) (var-get reputation-threshold-premium))) ERR_INSUFFICIENT_REPUTATION)
        
        (map-set knowledge-base { knowledge-id: new-knowledge-id }
            {
                contributor: tx-sender,
                title: title,
                description: description,
                knowledge-type: knowledge-type,
                category: category,
                access-level: access-level,
                price: price,
                quality-score: u0,
                download-count: u0,
                total-earnings: u0,
                ipfs-hash: ipfs-hash,
                ai-verified: false,
                created-at: burn-block-height,
                updated-at: burn-block-height,
                tags: tags
            }
        )
        
        ;; Update user stats
        (map-set user-profiles { user: tx-sender }
            (merge user-profile {
                total-contributions: (+ (get total-contributions user-profile) u1),
                last-active: burn-block-height
            })
        )
        
        (var-set knowledge-counter new-knowledge-id)
        (ok new-knowledge-id)
    )
)

;; Register AI model with detailed metadata
(define-public (register-ai-model
    (knowledge-id uint)
    (model-type (string-ascii 64))
    (framework (string-ascii 32))
    (version (string-ascii 16))
    (performance-metrics (string-ascii 256))
    (training-data-info (string-ascii 512))
    (computational-requirements (string-ascii 256))
    (license-type (string-ascii 32)))
    (let 
        (
            (knowledge-item (unwrap! (map-get? knowledge-base { knowledge-id: knowledge-id }) ERR_KNOWLEDGE_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get contributor knowledge-item)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get knowledge-type knowledge-item) TYPE_AI_MODEL) ERR_INVALID_PARAMETERS)
        
        (map-set ai-model-registry { knowledge-id: knowledge-id }
            {
                model-type: model-type,
                framework: framework,
                version: version,
                performance-metrics: performance-metrics,
                training-data-info: training-data-info,
                computational-requirements: computational-requirements,
                license-type: license-type
            }
        )
        (ok true)
    )
)

;; Purchase/Access knowledge
(define-public (access-knowledge (knowledge-id uint))
    (let 
        (
            (knowledge-item (unwrap! (map-get? knowledge-base { knowledge-id: knowledge-id }) ERR_KNOWLEDGE_NOT_FOUND))
            (user-profile (unwrap! (map-get? user-profiles { user: tx-sender }) ERR_UNAUTHORIZED))
            (price (get price knowledge-item))
            (contributor (get contributor knowledge-item))
        )
        ;; Check if already has access
        (asserts! (is-none (map-get? knowledge-access { knowledge-id: knowledge-id, user: tx-sender })) ERR_ALREADY_VOTED)
        
        ;; Handle payment for premium content
        (if (> price u0)
            (begin
                (asserts! (>= (stx-get-balance tx-sender) price) ERR_INSUFFICIENT_FUNDS)
                (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
                
                ;; Calculate platform fee and contributor payment
                (let 
                    (
                        (platform-fee (/ (* price (var-get platform-fee-percentage)) u100))
                        (contributor-payment (- price platform-fee))
                    )
                    ;; Pay contributor
                    (try! (as-contract (stx-transfer? contributor-payment tx-sender contributor)))
                    
                    ;; Update knowledge item earnings
                    (map-set knowledge-base { knowledge-id: knowledge-id }
                        (merge knowledge-item {
                            total-earnings: (+ (get total-earnings knowledge-item) contributor-payment),
                            download-count: (+ (get download-count knowledge-item) u1)
                        })
                    )
                    
                    ;; Update contributor earnings
                    (let 
                        (
                            (contributor-profile (unwrap! (map-get? user-profiles { user: contributor }) ERR_UNAUTHORIZED))
                        )
                        (map-set user-profiles { user: contributor }
                            (merge contributor-profile {
                                total-earnings: (+ (get total-earnings contributor-profile) contributor-payment),
                                reputation-score: (+ (get reputation-score contributor-profile) u10)
                            })
                        )
                    )
                )
            )
            ;; Free content - just update download count
            (map-set knowledge-base { knowledge-id: knowledge-id }
                (merge knowledge-item {
                    download-count: (+ (get download-count knowledge-item) u1)
                })
            )
        )
        
        ;; Grant access
        (map-set knowledge-access { knowledge-id: knowledge-id, user: tx-sender }
            {
                access-granted-at: burn-block-height,
                payment-amount: price,
                access-type: u1, ;; purchased
                expires-at: none
            }
        )
        
        ;; Update user download count
        (map-set user-profiles { user: tx-sender }
            (merge user-profile {
                total-downloads: (+ (get total-downloads user-profile) u1),
                last-active: burn-block-height
            })
        )
        
        (ok true)
    )
)

;; Rate and review knowledge
(define-public (rate-knowledge 
    (knowledge-id uint)
    (vote-score uint)
    (review-text (string-ascii 512)))
    (let 
        (
            (knowledge-item (unwrap! (map-get? knowledge-base { knowledge-id: knowledge-id }) ERR_KNOWLEDGE_NOT_FOUND))
            (user-profile (unwrap! (map-get? user-profiles { user: tx-sender }) ERR_UNAUTHORIZED))
        )
        (asserts! (and (>= vote-score u1) (<= vote-score u5)) ERR_INVALID_PARAMETERS)
        (asserts! (is-some (map-get? knowledge-access { knowledge-id: knowledge-id, user: tx-sender })) ERR_ACCESS_DENIED)
        (asserts! (is-none (map-get? knowledge-votes { knowledge-id: knowledge-id, voter: tx-sender })) ERR_ALREADY_VOTED)
        
        (map-set knowledge-votes { knowledge-id: knowledge-id, voter: tx-sender }
            {
                vote-score: vote-score,
                review-text: review-text,
                helpfulness-votes: u0,
                voted-at: burn-block-height
            }
        )
        
        ;; Update knowledge quality score (simplified average)
        (let 
            (
                (current-quality (get quality-score knowledge-item))
                (current-downloads (get download-count knowledge-item))
                (new-quality-score (if (is-eq current-downloads u0) 
                                     vote-score 
                                     (/ (+ (* current-quality current-downloads) vote-score) (+ current-downloads u1))))
            )
            (map-set knowledge-base { knowledge-id: knowledge-id }
                (merge knowledge-item { quality-score: new-quality-score })
            )
        )
        
        ;; Update user last active
        (map-set user-profiles { user: tx-sender }
            (merge user-profile { last-active: burn-block-height })
        )
        
        (ok true)
    )
)

;; Create knowledge collection
(define-public (create-knowledge-collection
    (collection-name (string-ascii 64))
    (description (string-ascii 512))
    (knowledge-ids (list 20 uint))
    (public bool))
    (let 
        (
            (user-profile (unwrap! (map-get? user-profiles { user: tx-sender }) ERR_UNAUTHORIZED))
            (collection-id (+ burn-block-height (len knowledge-ids))) ;; Simple ID generation
        )
        (asserts! (> (len collection-name) u0) ERR_INVALID_PARAMETERS)
        
        (map-set knowledge-collections { collection-id: collection-id, owner: tx-sender }
            {
                collection-name: collection-name,
                description: description,
                knowledge-ids: knowledge-ids,
                public: public,
                created-at: burn-block-height
            }
        )
        
        (map-set user-profiles { user: tx-sender }
            (merge user-profile { last-active: burn-block-height })
        )
        
        (ok collection-id)
    )
)

;; Update user premium status
(define-public (upgrade-to-premium)
    (let 
        (
            (user-profile (unwrap! (map-get? user-profiles { user: tx-sender }) ERR_UNAUTHORIZED))
            (premium-fee u50000) ;; 50,000 microSTX for premium
        )
        (asserts! (not (get premium-member user-profile)) ERR_INVALID_PARAMETERS)
        (asserts! (>= (stx-get-balance tx-sender) premium-fee) ERR_INSUFFICIENT_FUNDS)
        
        ;; Transfer premium fee
        (try! (stx-transfer? premium-fee tx-sender (as-contract tx-sender)))
        
        (map-set user-profiles { user: tx-sender }
            (merge user-profile { 
                premium-member: true,
                last-active: burn-block-height
            })
        )
        (ok true)
    )
)

;; Gift knowledge access
(define-public (gift-knowledge-access (knowledge-id uint) (recipient principal))
    (let 
        (
            (knowledge-item (unwrap! (map-get? knowledge-base { knowledge-id: knowledge-id }) ERR_KNOWLEDGE_NOT_FOUND))
            (gifter-profile (unwrap! (map-get? user-profiles { user: tx-sender }) ERR_UNAUTHORIZED))
            (price (get price knowledge-item))
        )
        ;; Check if recipient already has access
        (asserts! (is-none (map-get? knowledge-access { knowledge-id: knowledge-id, user: recipient })) ERR_ALREADY_VOTED)
        
        ;; Gifter must pay if it's premium content
        (if (> price u0)
            (begin
                (asserts! (>= (stx-get-balance tx-sender) price) ERR_INSUFFICIENT_FUNDS)
                (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
                
                ;; Pay contributor
                (let 
                    (
                        (platform-fee (/ (* price (var-get platform-fee-percentage)) u100))
                        (contributor-payment (- price platform-fee))
                    )
                    (try! (as-contract (stx-transfer? contributor-payment tx-sender (get contributor knowledge-item))))
                )
            )
            true
        )
        
        ;; Grant access to recipient
        (map-set knowledge-access { knowledge-id: knowledge-id, user: recipient }
            {
                access-granted-at: burn-block-height,
                payment-amount: price,
                access-type: u3, ;; gifted
                expires-at: none
            }
        )
        
        ;; Update download count
        (map-set knowledge-base { knowledge-id: knowledge-id }
            (merge knowledge-item {
                download-count: (+ (get download-count knowledge-item) u1)
            })
        )
        
        (ok true)
    )
)

;; Read-only functions

(define-read-only (get-knowledge-item (knowledge-id uint))
    (map-get? knowledge-base { knowledge-id: knowledge-id })
)

(define-read-only (get-user-profile (user principal))
    (map-get? user-profiles { user: user })
)

(define-read-only (get-ai-model-details (knowledge-id uint))
    (map-get? ai-model-registry { knowledge-id: knowledge-id })
)

(define-read-only (get-knowledge-access (knowledge-id uint) (user principal))
    (map-get? knowledge-access { knowledge-id: knowledge-id, user: user })
)

(define-read-only (get-knowledge-review (knowledge-id uint) (voter principal))
    (map-get? knowledge-votes { knowledge-id: knowledge-id, voter: voter })
)

(define-read-only (get-platform-stats)
    {
        total-knowledge-items: (var-get knowledge-counter),
        total-users: (var-get user-counter),
        platform-fee: (var-get platform-fee-percentage),
        min-price: (var-get min-contribution-price),
        ai-verification-enabled: (var-get ai-verification-enabled)
    }
)

(define-read-only (has-knowledge-access (knowledge-id uint) (user principal))
    (is-some (map-get? knowledge-access { knowledge-id: knowledge-id, user: user }))
)

;; Search knowledge by category (returns knowledge IDs - simplified)
(define-read-only (get-knowledge-counter)
    (var-get knowledge-counter)
)

;; Admin functions (contract owner only)
(define-public (update-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= new-fee u20) ERR_INVALID_PARAMETERS) ;; Max 20% fee
        (var-set platform-fee-percentage new-fee)
        (ok true)
    )
)

(define-public (verify-ai-researcher (researcher principal))
    (let 
        (
            (user-profile (unwrap! (map-get? user-profiles { user: researcher }) ERR_UNAUTHORIZED))
        )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        
        (map-set user-profiles { user: researcher }
            (merge user-profile { 
                ai-researcher-verified: true,
                reputation-score: (+ (get reputation-score user-profile) u100)
            })
        )
        (ok true)
    )
)

(define-public (verify-ai-content (knowledge-id uint))
    (let 
        (
            (knowledge-item (unwrap! (map-get? knowledge-base { knowledge-id: knowledge-id }) ERR_KNOWLEDGE_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        
        (map-set knowledge-base { knowledge-id: knowledge-id }
            (merge knowledge-item { ai-verified: true })
        )
        (ok true)
    )
)

(define-public (update-reputation-threshold (new-threshold uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set reputation-threshold-premium new-threshold)
        (ok true)
    )
)