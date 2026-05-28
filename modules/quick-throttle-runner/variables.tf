# ============================================================================
# Inputs for quick-throttle-runner
# ============================================================================

variable "output_dir" {
  type        = string
  description = "Directory where apply.sh + clear.sh are emitted. Typically path.root in the caller. Scripts land at <output_dir>/.qv-limits/qv-throttle.{apply,clear}.sh."
}
