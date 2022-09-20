#
# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# seL4 capDL spec memory analyzer.

BEGIN {
  in_objects = 0;
  frame_types[1] = "elf";
  frame_types[2] = "bss";
  frame_types[3] = "ipc_buffer";
  frame_types[4] = "stack";
  frame_types[5] = "copyregion";
  frame_types[6] = "bootinfo";
  frame_types[7] = "mmio";
  DETAILS = 0;
}
/^objects.*{/ { in_objects = 1; }
in_objects && $3 == "frame" {
  component = $1;
  size = 0;
  switch (substr($4, 2)) {
    case /4k/: size = 4096; break;
    case /4M/: size = 4*1024*1024; break;
    default:
      print "Unknown frame size", substr($4, 2);
      break;
  }

  switch ($8) {
    case "CDL_FrameFill_BootInfo":
      split(component, a, "_");
      component = a[3] "_" a[4];
      frame_type = "bootinfo";
      break;
    case "CDL_FrameFill_FileData":
      sub(".*frame_", "", component);
      sub("_group_bin.*", "", component);
      frame_type = "elf";
      break;
    default: {
      switch (component) {
        case /_copy_region_/:
          sub("_copy_region.*", "", component);
          frame_type = "copyregion";
          break;
        case /_frame__camkes_ipc_buffer_/:
          sub("_frame__camkes_ipc_buffer.*", "", component);
          frame_type = "ipc_buffer";
          break;
        case /^stack__camkes_stack_/:
          sub("^stack__camkes_stack_", "", component);
          split(component, a, "_");
          component = a[1] "_" a[2];
          frame_type = "stack";
          break;
        case /_data_[0-9]_obj/:
          sub("_?[0-9]*_data_[0-9]_obj", "", component);
          sub("_mmio.*", "", component);
          frame_type = ($5 == "paddr:" ? "mmio" : "bss");
          break;
        default:
          if ($5 == "paddr:") {
            sub("_mmio.*", "", component);
            sub("_csr_.*", "", component);
            frame_type = "mmio";
          } else {
            sub(".*frame_", "", component);
            sub("_group_bin.*", "", component);
            frame_type = "bss";
          }
          break;
      }
      break;
    }
  }
  cur_component = component;
  if (frame_type != "copyregion" && frame_type != "mmio") {
    # NB: copyregion's are holes in the VSpace
    components[cur_component] += size;;
  }
  memory[cur_component, frame_type] += size;
}
in_objects && /^}/ { in_objects = 0; }

END {
  asorti(components, comps, "@ind_str_asc");
  total = 0;
  for (i in comps) {
    c = comps[i];
    ntypes = 0;
    # per-component breakdown by frame type
    for (j in frame_types) {
      t = frame_types[j];
      if (memory[c, t] != "") {
        if (DETAILS) {
          printf "%-36.36s %-14s %5.0f KiB\n", (ntypes > 0 ? "" : c), t, memory[c, t] / 1024.;
        }
        ntypes++;
      }
    }
    total += components[c];
    # per-component totals
    if (!DETAILS) {
        printf "%-36.36s %5.0f KiB (%s)\n", c, components[c] / 1024., components[c];
    } else if (ntypes > 1) {
        printf "%-36.36s %-14s %5.0f KiB (%s)\n", c, "total", components[c] / 1024., components[c];
    }
  }
  # overall total
  if (DETAILS) {
      printf "%-36.36s %-14s %5.0f KiB (%s)\n", "Total", "", total / 1024., total;
  } else {
      printf "%-36.36s %5.0f KiB (%s)\n", "Total", total / 1024., total;
  }
}
