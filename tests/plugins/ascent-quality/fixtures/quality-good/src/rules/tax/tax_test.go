package tax

import "testing"

func TestRate(t *testing.T) {
	if got := Rate(100); got != 8 {
		t.Errorf("Rate(100) = %d, want 8", got)
	}
}

func TestRateZero(t *testing.T) {
	checkRate(t, 0, 0)
}

func checkRate(t *testing.T, amount, want int) {
	t.Helper()
	if got := Rate(amount); got != want {
		t.Fatalf("Rate(%d) = %d, want %d", amount, got, want)
	}
}
