SCRIPTS_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ETISS_PERFSIM_DIR="$(dirname "$SCRIPTS_DIR")/etiss_perfsim"

$ETISS_PERFSIM_DIR/gen_vicuna.sh
$SCRIPTS_DIR/compact-schedule.py
$ETISS_PERFSIM_DIR/etiss-perf-sim/rebuild.sh