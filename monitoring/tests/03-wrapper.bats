#!/usr/bin/env bats

RRDSTORM_DIR="$(cd "${BATS_TEST_DIRNAME}/../co2/local/rrdstorm" && pwd)"

@test "wrapper.sh fails on invalid command" {
    run "${RRDSTORM_DIR}/wrapper.sh" fake_command 0
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR: Unknown command 'fake_command'"* ]]
}

@test "wrapper.sh handles missing metadata gracefully" {
    run "${RRDSTORM_DIR}/wrapper.sh" update 999
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning: No metadata file found for index 999"* ]]
}
