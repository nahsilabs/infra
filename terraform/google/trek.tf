resource "google_project_service" "trek" {
  for_each = toset([
    "apikeys.googleapis.com",
    "places.googleapis.com",
  ])

  service = each.value

  disable_on_destroy = false
}

resource "google_apikeys_key" "trek" {
  name         = "trek-places"
  display_name = "TREK Places API"

  restrictions {
    # TREK sends Referer: $APP_URL on its server-side calls, so restrict by
    # referrer, not IP. APP_URL is set to https://trek.nahsi.dev.
    browser_key_restrictions {
      allowed_referrers = ["https://trek.nahsi.dev/*"]
    }

    api_targets {
      service = "places.googleapis.com"
    }
  }

  depends_on = [google_project_service.trek]
}

output "trek_places_api_key" {
  description = "Paste into TREK Admin -> Settings -> API Keys. Read with: terraform output -raw trek_places_api_key"
  value       = google_apikeys_key.trek.key_string
  sensitive   = true
}
