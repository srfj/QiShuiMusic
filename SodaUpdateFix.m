#import <objc/runtime.h>
#import <mach-o/dyld.h>

// 汽水音乐 (com.soda.music) 强制升级弹窗屏蔽
//
// 更新检查：-[TTAppUpdateHelper startCheckVersion]
//           -[TTAppUpdateHelperDefault startCheckVersion]
// 弹窗展示：-[TTAppUpdateHelperDefault showUpdateViewWithModel:error:]
//           -[TTAppUpdateHelperDefault showWithModel:]
//           -[STOuterTest.STAppUpdateHelper showUpdateViewWithModel:error:]

static void hook_method(Class cls, const char *selName, IMP newImp) {
    if (!cls) return;
    Method m = class_getInstanceMethod(cls, sel_registerName(selName));
    if (m) {
        method_setImplementation(m, newImp);
    }
}

static void hook_start_check_version(id self, SEL _cmd) {
    (void)self;
    (void)_cmd;
}

static void hook_show_update_view(id self, SEL _cmd, id model, id error) {
    (void)self;
    (void)_cmd;
    (void)model;
    (void)error;
}

static void hook_show_with_model(id self, SEL _cmd, id model) {
    (void)self;
    (void)_cmd;
    (void)model;
}

static Class find_class(const char *runtimeName, const char *swiftName) {
    Class cls = objc_getClass(runtimeName);
    if (!cls && swiftName) {
        cls = objc_getClass(swiftName);
    }
    return cls;
}

static void install_hooks(void) {
    Class helper = find_class("TTAppUpdateHelper", NULL);
    Class helperDefault = find_class("TTAppUpdateHelperDefault", NULL);
    Class swiftHelper = find_class("_TtC11STOuterTest17STAppUpdateHelper",
                                   "STOuterTest.STAppUpdateHelper");

    hook_method(helper, "startCheckVersion", (IMP)hook_start_check_version);
    hook_method(helperDefault, "startCheckVersion", (IMP)hook_start_check_version);

    hook_method(helperDefault, "showUpdateViewWithModel:error:", (IMP)hook_show_update_view);
    hook_method(helperDefault, "showWithModel:", (IMP)hook_show_with_model);

    hook_method(swiftHelper, "showUpdateViewWithModel:error:", (IMP)hook_show_update_view);
}

static void on_image_added(const struct mach_header *mh, intptr_t slide) {
    (void)mh;
    (void)slide;
    install_hooks();
}

__attribute__((constructor)) static void soda_update_fix_init(void) {
    install_hooks();
    _dyld_register_func_for_add_image(on_image_added);
}
