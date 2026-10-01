import importlib.util
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
HELPER = ROOT / ".github" / "scripts" / "android_runtime_smoke_launch.py"
NAVIGATION_HELPER = ROOT / ".github" / "scripts" / "android_runtime_smoke_navigation.py"
SMOKE_SCRIPT = ROOT / ".github" / "scripts" / "android_runtime_smoke.sh"
WORKFLOW = ROOT / ".github" / "workflows" / "android_runtime_smoke.yml"


def load_helper():
    spec = importlib.util.spec_from_file_location("android_runtime_smoke_launch", HELPER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_navigation_helper():
    spec = importlib.util.spec_from_file_location(
        "android_runtime_smoke_navigation", NAVIGATION_HELPER
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class RuntimeSmokeLaunchTest(unittest.TestCase):
    def test_video_card_selector_chooses_card_not_its_popup_menu(self):
        helper = load_navigation_helper()
        ui = """<hierarchy>
          <node class="android.widget.ImageView" clickable="true"
            content-desc="22:25\n阿房宫赋\n播放\nUP：子非秋月"
            bounds="[32,406][530,954]" />
          <node class="android.widget.Button" clickable="true"
            content-desc="显示菜单" bounds="[466,883][543,959]" />
          <node class="android.widget.ImageView" clickable="true"
            content-desc="00:57\n方便面\n播放\nUP：日食记"
            bounds="[551,406][1049,954]" />
        </hierarchy>"""

        target = helper.find_first_video_card(ui)

        self.assertEqual(target["bounds"], "[32,406][530,954]")
        self.assertEqual((target["cx"], target["cy"]), (281, 680))

    def test_video_card_selector_fails_when_no_clickable_video_card_exists(self):
        helper = load_navigation_helper()

        self.assertIsNone(
            helper.find_first_video_card(
                '<hierarchy><node clickable="true" content-desc="显示菜单" '
                'bounds="[10,10][80,80]" /></hierarchy>'
            )
        )

    def test_detail_more_selector_chooses_toolbar_over_related_card_menus(self):
        helper = load_navigation_helper()
        ui = """<hierarchy rotation="0">
          <node class="android.widget.FrameLayout" bounds="[0,0][1080,2400]">
          <node class="android.widget.Button" clickable="true"
            content-desc="返回主页" bounds="[110,157][221,246]" />
          <node class="android.widget.Button" clickable="true"
            content-desc="显示菜单" bounds="[954,139][1080,265]" />
          <node class="android.widget.ImageView" clickable="true"
            content-desc="46:37\n徐光启\n播放\nUP：子非秋月"
            bounds="[0,1452][1080,1741]">
            <node class="android.widget.Button" clickable="true"
              content-desc="显示菜单" bounds="[972,1665][1049,1741]" />
          </node>
          </node>
        </hierarchy>"""

        target = helper.find_video_detail_more_button(ui)

        self.assertEqual(target["bounds"], "[954,139][1080,265]")
        self.assertEqual((target["cx"], target["cy"]), (1017, 202))

    def test_detail_more_selector_rejects_recommendation_feed(self):
        helper = load_navigation_helper()

        self.assertIsNone(
            helper.find_video_detail_more_button(
                '<hierarchy><node clickable="true" content-desc="显示菜单" '
                'bounds="[954,139][1080,265]" /></hierarchy>'
            )
        )

    def test_temp_quiet_scenario_navigates_to_detail_before_opening_its_menu(self):
        script = SMOKE_SCRIPT.read_text(encoding="utf-8")

        self.assertIn("android_runtime_smoke_navigation.py --video-card", script)
        self.assertIn('grep -q "返回主页" "$current_ui" && open_more_from_ui', script)
        self.assertIn("android_runtime_smoke_navigation.py --detail-more-menu", script)
        self.assertIn("action=tap_recommendation_video_card", script)

    def test_dev_package_fallback_uses_real_activity_class(self):
        helper = load_helper()

        component = helper.resolve_launcher_component(
            package_name="com.example.piliplus.dev",
            resolved_launcher="",
            manifest_package="com.example.piliplus",
            manifest_activity=".MainActivity",
        )

        self.assertEqual(component, "com.example.piliplus.dev/com.example.piliplus.MainActivity")

    def test_default_package_fallback_still_launches_main_activity(self):
        helper = load_helper()

        component = helper.resolve_launcher_component(
            package_name="com.example.piliplus",
            resolved_launcher="",
            manifest_package="com.example.piliplus",
            manifest_activity=".MainActivity",
        )

        self.assertEqual(component, "com.example.piliplus/com.example.piliplus.MainActivity")

    def test_package_manager_resolution_is_preferred(self):
        helper = load_helper()

        component = helper.resolve_launcher_component(
            package_name="com.example.piliplus.dev",
            resolved_launcher="component=com.example.piliplus.dev/com.example.piliplus.MainActivity",
            manifest_package="wrong.package",
            manifest_activity=".WrongActivity",
        )

        self.assertEqual(component, "com.example.piliplus.dev/com.example.piliplus.MainActivity")

    def test_missing_launcher_activity_fails_clearly(self):
        helper = load_helper()

        with self.assertRaisesRegex(ValueError, "launcher activity"):
            helper.resolve_launcher_component(
                package_name="com.example.piliplus.dev",
                resolved_launcher="",
                manifest_package="com.example.piliplus",
                manifest_activity="",
            )

    def test_smoke_script_no_longer_hardcodes_relative_main_activity(self):
        script = SMOKE_SCRIPT.read_text(encoding="utf-8")

        self.assertNotIn('${PACKAGE_NAME}/.MainActivity', script)
        self.assertIn("android_runtime_smoke_launch.py", script)

    def test_workflow_requires_an_explicit_source_build(self):
        workflow = WORKFLOW.read_text(encoding="utf-8")

        self.assertIn("  workflow_dispatch:", workflow)
        self.assertNotIn("  push:", workflow)
        self.assertIn("ARTIFACT_RUN_ID: ${{ inputs.artifact_run_id }}", workflow)
        self.assertIn('.head_sha == $sha and .conclusion == "success"', workflow)


if __name__ == "__main__":
    unittest.main()
