#pragma once

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <mutex>
#include <thread>

#include "ring_buffer.h"

namespace sw {

struct PlaybackConfig {
  int sample_rate = 48000;
  int channels = 2;
  int frames_per_buffer = 0;  // if 0, a default will be chosen.
};

// Minimal playback loop simulator: pulls PCM frames from RingBuffer and advances clock.
class PlaybackThread {
 public:
  PlaybackThread(RingBuffer& buffer, PlaybackConfig config);
  ~PlaybackThread();

  PlaybackThread(const PlaybackThread&) = delete;
  PlaybackThread& operator=(const PlaybackThread&) = delete;

  // Starts the playback loop thread. Returns false on invalid config or if already running.
  bool Start();
  // Stops and joins the playback loop.
  void Stop();
  bool running() const { return running_.load(); }

  // Current playback position in milliseconds (accumulated).
  int64_t position_ms() const { return position_ms_.load(); }
  void ResetPosition(int64_t position_ms = 0) { position_ms_.store(position_ms); }

  // Optional callback invoked when position advances; called from playback thread.
  void SetPositionCallback(std::function<void(int64_t)> cb);

 private:
  void ThreadMain();

  RingBuffer& buffer_;
  PlaybackConfig cfg_;

  std::thread thread_;
  std::atomic<bool> running_{false};
  std::atomic<int64_t> position_ms_{0};

  std::function<void(int64_t)> pos_cb_;
  mutable std::mutex cb_mu_;
};

}  // namespace sw
