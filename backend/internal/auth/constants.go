package auth

import "time"

const AccessTokenDuration = 15 * time.Minute
const RefreshTokenDuration = 30 * 24 * time.Hour
