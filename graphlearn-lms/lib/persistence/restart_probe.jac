"""Small deterministic graph probe used by the cross-process persistence test."""

import os;

node PersistenceProbe {
    has probe_id: str;
    has value: str;
}

with entry:__main__ {
    probe_id = os.getenv("GRAPHLEARN_PROBE_ID", "graphlearn-restart-probe");
    mode = os.getenv("GRAPHLEARN_PROBE_MODE", "read");
    probes: list[PersistenceProbe] = [];
    for stored_probe in [root -->][?:PersistenceProbe] {
        if stored_probe.probe_id == probe_id {
            probes = probes + [stored_probe];
        }
    }
    if mode == "write" {
        if len(probes) == 0 {
            probe = (root ++> PersistenceProbe(probe_id=probe_id, value="durable"))[0];
        } else {
            probe = probes[0];
            probe.value = "durable";
        }
        commit();
        print("PERSISTENCE_PROBE_WRITE", probe.probe_id, jid(probe));
    } else {
        if len(probes) != 1 or probes[0].value != "durable" {
            raise Exception("Persistent graph probe was not restored.");
        }
        print("PERSISTENCE_PROBE_READ", probes[0].probe_id, jid(probes[0]));
    }
}
