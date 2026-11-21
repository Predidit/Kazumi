#include <dlfcn.h>
#include <jni.h>
#include <vulkan/vulkan.h>

#include <algorithm>
#include <cstdio>
#include <string>
#include <vector>

namespace {

struct Loader {
  void* handle = dlopen("libvulkan.so", RTLD_NOW | RTLD_LOCAL);
  ~Loader() {
    if (handle) dlclose(handle);
  }
};

struct Instance {
  VkInstance handle{};
  PFN_vkDestroyInstance destroy{};
  ~Instance() {
    if (handle && destroy) destroy(handle, nullptr);
  }
};

struct Adapter {
  std::string id, name, vendor, api;
};

std::string ToUuid(const uint8_t* bytes) {
  constexpr char kHex[] = "0123456789abcdef";
  std::string uuid;
  uuid.reserve(36);
  for (size_t i = 0; i < VK_UUID_SIZE; i++) {
    if (i == 4 || i == 6 || i == 8 || i == 10) uuid.push_back('-');
    uuid.push_back(kHex[bytes[i] >> 4]);
    uuid.push_back(kHex[bytes[i] & 15]);
  }
  return uuid;
}

std::vector<Adapter> Enumerate() {
  Loader loader;
  if (!loader.handle) return {};
  // Load dynamically: Vulkan remains an optional capability of the APK.
  const auto get = reinterpret_cast<PFN_vkGetInstanceProcAddr>(
      dlsym(loader.handle, "vkGetInstanceProcAddr"));
  if (!get) return {};
  const auto version = reinterpret_cast<PFN_vkEnumerateInstanceVersion>(
      get(VK_NULL_HANDLE, "vkEnumerateInstanceVersion"));
  uint32_t available = VK_API_VERSION_1_0;
  if (!version || version(&available) != VK_SUCCESS || available < VK_API_VERSION_1_2) {
    return {};
  }
  VkApplicationInfo app{};
  app.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
  app.pApplicationName = "Kazumi video GPU probe";
  app.apiVersion = VK_API_VERSION_1_2;
  VkInstanceCreateInfo info{};
  info.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
  info.pApplicationInfo = &app;
  const auto create = reinterpret_cast<PFN_vkCreateInstance>(
      get(VK_NULL_HANDLE, "vkCreateInstance"));
  Instance instance;
  if (!create || create(&info, nullptr, &instance.handle) != VK_SUCCESS) return {};
  const auto handle = instance.handle;
  instance.destroy = reinterpret_cast<PFN_vkDestroyInstance>(get(handle, "vkDestroyInstance"));
  const auto enumerate = reinterpret_cast<PFN_vkEnumeratePhysicalDevices>(
      get(handle, "vkEnumeratePhysicalDevices"));
  const auto properties = reinterpret_cast<PFN_vkGetPhysicalDeviceProperties2>(
      get(handle, "vkGetPhysicalDeviceProperties2"));
  const auto queues = reinterpret_cast<PFN_vkGetPhysicalDeviceQueueFamilyProperties>(
      get(handle, "vkGetPhysicalDeviceQueueFamilyProperties"));
  if (!enumerate || !properties || !queues) return {};

  uint32_t count = 0;
  if (enumerate(handle, &count, nullptr) != VK_SUCCESS || count == 0 || count > 256) {
    return {};
  }
  std::vector<VkPhysicalDevice> devices(count);
  if (enumerate(handle, &count, devices.data()) != VK_SUCCESS) return {};
  std::vector<Adapter> result;
  for (uint32_t idx = 0; idx < count; idx++) {
    const auto gpu = devices[idx];
    VkPhysicalDeviceIDProperties id{};
    id.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_ID_PROPERTIES;
    VkPhysicalDeviceProperties2 props{};
    props.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
    props.pNext = &id;
    properties(gpu, &props);
    const auto& physical = props.properties;
    if (physical.deviceType == VK_PHYSICAL_DEVICE_TYPE_CPU ||
        physical.apiVersion < VK_API_VERSION_1_2 || physical.deviceName[0] == '\0' ||
        std::all_of(id.deviceUUID, id.deviceUUID + VK_UUID_SIZE, [](uint8_t b) { return b == 0; })) {
      continue;
    }
    uint32_t family_count = 0;
    queues(gpu, &family_count, nullptr);
    if (family_count == 0 || family_count > 256) continue;
    std::vector<VkQueueFamilyProperties> families(family_count);
    queues(gpu, &family_count, families.data());
    // libplacebo shader rendering requires a graphics queue.
    if (std::none_of(families.begin(), families.begin() + family_count,
                     [](const auto& p) { return (p.queueFlags & VK_QUEUE_GRAPHICS_BIT) != 0; })) {
      continue;
    }
    const auto api = physical.apiVersion;
    char text[32];
    std::snprintf(text, sizeof(text), "%u.%u.%u", VK_API_VERSION_MAJOR(api),
                  VK_API_VERSION_MINOR(api), VK_API_VERSION_PATCH(api));
    result.push_back({ToUuid(id.deviceUUID), physical.deviceName,
                      std::to_string(physical.vendorID), text});
  }
  return result;
}

}  // namespace

extern "C" JNIEXPORT jobjectArray JNICALL
Java_com_example_kazumi_VideoGpu_enumerateVulkan(JNIEnv* env, jobject /*receiver*/) {
  const auto adapters = Enumerate();
  jclass string_class = env->FindClass("java/lang/String");
  jclass row_class = env->FindClass("[Ljava/lang/String;");
  if (!string_class || !row_class) return nullptr;
  jobjectArray list = env->NewObjectArray(static_cast<jsize>(adapters.size()), row_class, nullptr);
  if (!list) return nullptr;
  for (size_t i = 0; i < adapters.size(); ++i) {
    const auto& gpu = adapters[i];
    const std::string* fields[] = {&gpu.id, &gpu.name, &gpu.vendor, &gpu.api};
    jobjectArray row = env->NewObjectArray(4, string_class, nullptr);
    if (!row) return nullptr;
    for (jsize field = 0; field < 4; ++field) {
      const auto item = env->NewStringUTF(fields[field]->c_str());
      if (!item) return nullptr;
      env->SetObjectArrayElement(row, field, item);
      env->DeleteLocalRef(item);
    }
    env->SetObjectArrayElement(list, static_cast<jsize>(i), row);
    env->DeleteLocalRef(row);
  }
  return list;
}
