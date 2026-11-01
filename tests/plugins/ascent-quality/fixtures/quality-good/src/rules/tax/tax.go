package tax

// Rate returns the tax on an amount in cents.
func Rate(amount int) int {
	return amount * 8 / 100
}
