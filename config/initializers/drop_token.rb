# frozen_string_literal: true

DROP_TOKEN_CONFIG = YAML.load_file("#{Rails.root.to_s}/config/drop_token.yml").with_indifferent_access