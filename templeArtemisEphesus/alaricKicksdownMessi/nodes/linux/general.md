title: what is `/dev/shm`?
creationDate: 2026-09-05 22:30
body: at the creation time of this node, on my current NixOS config, `/dev/shm` is a 7.6 GB tmpfs, mounted with rw,nosuid,nodev.
It is used to host `podman`'s rootless lockfile. From `glm-5.3-flash`:
 /dev/shm is used wherever programs need fast, ephemeral, file-shaped data that outlives a single process but should not persist. Common uses:     
                                                                                                                                                   
 1. Inter-process shared memory (its namesake purpose)                                                                                             
                                                                                                                                                   
 Programs call shm_open("/foo"), which creates /dev/shm/foo, then mmap() it so two processes can share a memory region directly — much faster than 
 pipes or sockets for large amounts of data. Used by:                                                                                              
 - Browsers (Chrome/Firefox) for shared buffers between processes                                                                                  
 - Multimedia frameworks (GStreamer, PipeWire, PulseAudio — e.g. /dev/shm/pulse-shm-*)                                                             
 - Databases (PostgreSQL uses its own shm mechanisms, but many engines use POSIX shm for buffer sharing)                                           
                                                                                                                                                   
 2. Locks and synchronization primitives                                                                                                           
                                                                                                                                                   
 Small files used as mutexes/semaphores across processes. You saw this on your own system:                                                         
 - libpod_rootless_lock_1000 — Podman's rootless lock file                                                                                         
 - lttng-ust-wait-* — LTTng tracing wakeup pipes                                                                                                   
                                                                                                                                                   
 3. Scratch space for fast, throwaway data                                                                                                         
                                                                                                                                                   
 Tools that want temporary files with no disk I/O cost and no cleanup worries:                                                                     
 - Temp decompression targets, video render intermediates, build caches                                                                            
 - Test suites that create "files" without polluting disk                                                                                          
                                                                                                                                                   
 4. Runtime secrets and socket-like handoffs                                                                                                       
                                                                                                                                                   
 Data meant to exist only for the duration of a session — passwords handed from a helper to a main process, session keys, etc. Exactly the use     
 case relevant to your fw_cfg API-key discussion.
--
