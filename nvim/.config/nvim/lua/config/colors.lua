local ok, c = pcall(require, "config.matugen_colors")
if ok and c then return c end

-- Nord-Fallback
return {
  primary              = "#81a1c1",
  on_primary           = "#2e3440",
  primary_container    = "#3b4252",
  on_primary_container = "#d8dee9",
  secondary            = "#a3be8c",
  on_secondary         = "#2e3440",
  secondary_container  = "#434c5e",
  on_secondary_container = "#eceff4",
  tertiary             = "#ebcb8b",
  on_tertiary          = "#2e3440",
  tertiary_container   = "#4c566a",
  on_tertiary_container = "#eceff4",
  error                = "#bf616a",
  on_error             = "#eceff4",
  error_container      = "#4c1515",
  on_error_container   = "#eceff4",
  surface              = "#3b4252",
  on_surface           = "#eceff4",
  surface_variant      = "#434c5e",
  on_surface_variant   = "#d8dee9",
  outline              = "#4c566a",
  outline_variant      = "#3b4252",
  inverse_surface      = "#eceff4",
  inverse_on_surface   = "#2e3440",
  inverse_primary      = "#2e3440",
}
