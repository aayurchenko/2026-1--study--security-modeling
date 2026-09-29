const experiment_params = Dict(
    :n => 20,
    :edge_prob => 0.2,
    :source => 1,
    :target => 20,
    :cvss_scores => Dict(
        (1, 3) => 0.9,
        (2, 5) => 0.7,
        (3, 8) => 0.8,
        (5, 20) => 0.95,
    ),
    :trust_relations => [(4, 6), (6, 10), (10, 15)],
)