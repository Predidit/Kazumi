"""Install Kazumi's frame interpolation filter into a checked-out mpv source tree before Meson configure."""
from pathlib import Path
import argparse
import shutil

HERE = Path(__file__).resolve().parent


def replace_once(path, old, new):
    text = path.read_text(encoding="utf-8")
    if new in text:
        return
    if text.count(old) != 1:
        raise ValueError(f"Unexpected mpv layout in {path}: {old!r}")
    path.write_text(text.replace(old, new), encoding="utf-8", newline="\n")


def install_android_surface_resize(mpv):
    options = mpv / "options/options.c"
    surface_size = '    {"android-surface-size", OPT_SIZE_BOX(android_surface_size)},'
    replace_once(options, surface_size, surface_size +
                 '\n    {"kazumi-surface-size", OPT_ALIAS("android-surface-size")},')
    for backend in ("opengl", "vulkan"):
        context = mpv / f"video/out/{backend}/context_android.c"
        body = "static int android_control(struct ra_ctx *ctx, int *events, int request, void *arg)\n{\n    return VO_NOTIMPL;\n}"
        replace_once(context, body, """static int android_control(struct ra_ctx *ctx, int *events, int request, void *arg)
{
    if (request == VOCTRL_VO_OPTS_CHANGED && ctx->vo->dwidth > 0) {
        int width, height;
        if (vo_android_surface_size(ctx->vo, &width, &height) &&
            (width != ctx->vo->dwidth || height != ctx->vo->dheight) &&
            android_reconfig(ctx)) {
            *events |= VO_EVENT_RESIZE | VO_EVENT_EXPOSE;
            return VO_TRUE;
        }
    }
    return VO_NOTIMPL;
}""")


def install(mpv):
    meson = mpv / "meson.build"
    filters = mpv / "filters/user_filters.c"
    if not meson.is_file() or not filters.is_file():
        raise ValueError("Expected an mpv source checkout")
    install_android_surface_resize(mpv)
    # RGB -> YUV must use the output matrix, not the RGB input (which falls
    # back to BT.601). Otherwise interpolated frames are encoded in one matrix but
    # rendered with the source metadata, alternating brightness and hue.
    replace_once(mpv / "video/sws_utils.c",
        "int d_csp = pl_csp_to_sws_colorspace(src.repr.sys);",
        "int d_csp = pl_csp_to_sws_colorspace(dst.repr.sys);")
    replace_once(filters,
        "const struct mp_user_filter_entry *vf_list[] = {",
        "extern const struct mp_user_filter_entry vf_kazumi_rife;\n\n"
        "const struct mp_user_filter_entry *vf_list[] = {\n    &vf_kazumi_rife,")
    replace_once(meson,
        "    'video/filter/vf_format.c',",
        "    'video/filter/vf_format.c',\n"
        "    'video/filter/vf_kazumi_rife.c',\n"
        "    'video/filter/frame_plan.c',")
    for file in ("vf_kazumi_rife.c", "neural_runtime.h", "frame_plan.c", "frame_plan.h", "rife_bridge.h"):
        shutil.copyfile(HERE / file, mpv / "video/filter" / file)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mpv", type=Path)
    install(parser.parse_args().mpv)
