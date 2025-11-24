#include "decoder.h"

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswresample/swresample.h>
#include <libavutil/channel_layout.h>
}

#include <algorithm>
#include <memory>
#include <string>
#include <vector>

namespace sw {

namespace {

AVSampleFormat NormalizeSampleFormat(AVSampleFormat fmt) {
  // Prefer float planar/interleaved; otherwise fall back to 16-bit signed.
  switch (fmt) {
    case AV_SAMPLE_FMT_FLTP:
    case AV_SAMPLE_FMT_FLT:
      return fmt;
    default:
      return AV_SAMPLE_FMT_S16;
  }
}

class DecoderFFmpeg : public Decoder {
 public:
  ~DecoderFFmpeg() override { Close(); }

  bool Open(const std::string& source) override {
    Close();
    if (source.empty()) {
      last_status_ = Status::kInvalidArguments;
      return false;
    }
    fmt_ctx_ = avformat_alloc_context();
    if (avformat_open_input(&fmt_ctx_, source.c_str(), nullptr, nullptr) < 0) {
      last_status_ = Status::kIoError;
      return false;
    }
    if (avformat_find_stream_info(fmt_ctx_, nullptr) < 0) {
      last_status_ = Status::kError;
      return false;
    }
    audio_stream_idx_ = av_find_best_stream(fmt_ctx_, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
    if (audio_stream_idx_ < 0) {
      last_status_ = Status::kNotSupported;
      return false;
    }
    AVStream* stream = fmt_ctx_->streams[audio_stream_idx_];
    const AVCodec* codec = avcodec_find_decoder(stream->codecpar->codec_id);
    if (!codec) {
      last_status_ = Status::kNotSupported;
      return false;
    }
    codec_ctx_ = avcodec_alloc_context3(codec);
    if (!codec_ctx_) {
      last_status_ = Status::kError;
      return false;
    }
    if (avcodec_parameters_to_context(codec_ctx_, stream->codecpar) < 0) {
      last_status_ = Status::kError;
      return false;
    }
    if (avcodec_open2(codec_ctx_, codec, nullptr) < 0) {
      last_status_ = Status::kError;
      return false;
    }
    // Configure output.
    sample_rate_ = target_sample_rate_ > 0 ? target_sample_rate_ : codec_ctx_->sample_rate;
    channels_ = target_channels_ > 0 ? target_channels_ : codec_ctx_->ch_layout.nb_channels;
    if (channels_ == 0) {
      channels_ = 2;
    }
    // Build output channel layout.
    AVChannelLayout out_layout;
    av_channel_layout_default(&out_layout, channels_);
    AVSampleFormat out_fmt = AV_SAMPLE_FMT_FLT;
    if (swr_alloc_set_opts2(&swr_ctx_, &out_layout, out_fmt, sample_rate_, &codec_ctx_->ch_layout,
                            codec_ctx_->sample_fmt, codec_ctx_->sample_rate, 0, nullptr) < 0) {
      last_status_ = Status::kError;
      return false;
    }
    if (!swr_ctx_ || swr_init(swr_ctx_) < 0) {
      last_status_ = Status::kError;
      return false;
    }
    frame_ = av_frame_alloc();
    packet_ = av_packet_alloc();
    if (!frame_ || !packet_) {
      last_status_ = Status::kError;
      return false;
    }
    opened_ = true;
    last_status_ = Status::kOk;
    return true;
  }

  bool Read(PcmBuffer& out_buffer) override {
    if (!opened_) {
      last_status_ = Status::kInvalidState;
      return false;
    }
    while (true) {
      int ret = av_read_frame(fmt_ctx_, packet_);
      if (ret < 0) {
        // Flush decoder on EOF.
        avcodec_send_packet(codec_ctx_, nullptr);
        ret = avcodec_receive_frame(codec_ctx_, frame_);
        if (ret == AVERROR_EOF) {
          last_status_ = Status::kOk;
          return false;
        }
      } else if (packet_->stream_index != audio_stream_idx_) {
        av_packet_unref(packet_);
        continue;
      } else {
        if (avcodec_send_packet(codec_ctx_, packet_) < 0) {
          av_packet_unref(packet_);
          last_status_ = Status::kError;
          return false;
        }
        av_packet_unref(packet_);
        ret = avcodec_receive_frame(codec_ctx_, frame_);
      }

      if (ret == AVERROR(EAGAIN)) {
        continue;
      }
      if (ret < 0) {
        last_status_ = Status::kError;
        return false;
      }

      // Resample to interleaved float.
      const int out_samples =
          swr_get_out_samples(swr_ctx_, frame_->nb_samples > 0 ? frame_->nb_samples : 1024);
      out_buffer.interleaved.resize(static_cast<size_t>(out_samples * channels_));
      uint8_t* out_data[1] = {
          reinterpret_cast<uint8_t*>(out_buffer.interleaved.data()),
      };
      int converted = swr_convert(swr_ctx_,
                                  out_data,
                                  out_samples,
                                  const_cast<const uint8_t**>(frame_->data),
                                  frame_->nb_samples);
      if (converted < 0) {
        last_status_ = Status::kError;
        return false;
      }
      out_buffer.interleaved.resize(static_cast<size_t>(converted * channels_));
      out_buffer.sample_rate = sample_rate_;
      out_buffer.channels = channels_;
      last_status_ = Status::kOk;
      return true;
    }
  }

  void Close() override {
    if (packet_) {
      av_packet_free(&packet_);
    }
    if (frame_) {
      av_frame_free(&frame_);
    }
    if (swr_ctx_) {
      swr_free(&swr_ctx_);
    }
    if (codec_ctx_) {
      avcodec_free_context(&codec_ctx_);
    }
    if (fmt_ctx_) {
      avformat_close_input(&fmt_ctx_);
    }
    opened_ = false;
  }

  int sample_rate() const override { return sample_rate_; }
  int channels() const override { return channels_; }

  bool ConfigureOutput(int target_sample_rate, int target_channels) override {
    if (target_sample_rate <= 0 || target_channels <= 0) {
      last_status_ = Status::kInvalidArguments;
      return false;
    }
    target_sample_rate_ = target_sample_rate;
    target_channels_ = target_channels;
    last_status_ = Status::kOk;
    return true;
  }

  Status last_status() const override { return last_status_; }

 private:
  AVFormatContext* fmt_ctx_ = nullptr;
  AVCodecContext* codec_ctx_ = nullptr;
  SwrContext* swr_ctx_ = nullptr;
  AVFrame* frame_ = nullptr;
  AVPacket* packet_ = nullptr;
  int audio_stream_idx_ = -1;
  int target_sample_rate_ = 0;
  int target_channels_ = 0;
  int sample_rate_ = 48000;
  int channels_ = 2;
  bool opened_ = false;
  Status last_status_ = Status::kOk;
};

}  // namespace

std::unique_ptr<Decoder> CreateFFmpegDecoder() {
  return std::make_unique<DecoderFFmpeg>();
}

}  // namespace sw
