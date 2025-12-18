package gitlab.policy.image_hardening

# Require images to originate from approved private registries and be pinned by digest.
# Provide input.allowed_registries from CI (e.g., [$PRIVATE_REGISTRY, $SECURE_ANALYZERS_PREFIX]).

default allow := false

allowed_registries := {reg | reg := input.allowed_registries[_]}

allow {
  input.image_registry != ""
  input.image_reference != ""
  input.image_registry == allowed_registries[_]
  contains(input.image_reference, "@sha256:")
}

violation[msg] {
  not allow
  msg := sprintf("Image %s is not from an approved registry or not pinned by digest", [input.image_reference])
}
