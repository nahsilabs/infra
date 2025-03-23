resource "adguard_rewrite" "odroid-1" {
  domain = "odroid-1.local"
  answer = "10.2.10.10"
}

resource "adguard_rewrite" "odroid-2" {
  domain = "odroid-2.local"
  answer = "10.2.10.20"
}

resource "adguard_rewrite" "odroid-3" {
  domain = "odroid-3.local"
  answer = "10.2.10.30"
}

resource "adguard_rewrite" "heliopolis" {
  domain = "heliopolis.local"
  answer = "10.2.10.40"
}

resource "adguard_rewrite" "odyssey-0" {
  domain = "odyssey-0.local"
  answer = "10.2.10.50"
}
