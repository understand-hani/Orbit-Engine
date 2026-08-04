from app.schemas.common import SuggestedAction, TaskType
from app.schemas.research_feeder import ResearchDayRole
from app.schemas.tech_radar import RadarType


WEEKDAY_MONDAY = 0
WEEKDAY_TUESDAY = 1
WEEKDAY_WEDNESDAY = 2
WEEKDAY_THURSDAY = 3
WEEKDAY_FRIDAY = 4
WEEKDAY_SATURDAY = 5
WEEKDAY_SUNDAY = 6


WEEKDAY_NAMES = {
    WEEKDAY_MONDAY: "monday",
    WEEKDAY_TUESDAY: "tuesday",
    WEEKDAY_WEDNESDAY: "wednesday",
    WEEKDAY_THURSDAY: "thursday",
    WEEKDAY_FRIDAY: "friday",
    WEEKDAY_SATURDAY: "saturday",
    WEEKDAY_SUNDAY: "sunday",
}


PRODUCT_RADAR_TOPICS = [
    "ADAS",
    "车企技术路线",
    "World Model",
    "产品动态",
    "机器人产品",
    "法规",
]


PRODUCT_RADAR_COMPANIES = [
    "小米汽车",
    "理想汽车",
    "华为",
    "比亚迪",
    "DeepRoute",
    "Unitree",
    "AgiBot",
]


PRODUCT_RADAR_SIGNAL_TYPES = [
    "产品发布",
    "功能更新",
    "技术路线",
    "法规变化",
    "产品能力展示",
]


TECHNICAL_RADAR_TOPICS = [
    "World Model",
    "Driving Video Generation",
    "3DGS",
    "4DGS",
    "Simulation",
    "Embodied Intelligence",
]


TECHNICAL_RADAR_RESEARCH_GROUPS = [
    "Shanghai AI Lab",
    "Wayve",
    "NVIDIA",
    "academic labs",
]


TECHNICAL_RADAR_SIGNAL_TYPES = [
    "论文",
    "开源项目",
    "技术报告",
    "benchmark",
    "方法框架",
]


RESEARCH_DIRECTION = "3DGS / World Model / Driving Video Generation"
RESEARCH_PROJECT = "SLAM-Enhanced 4DGS Dynamic Scene Reconstruction"


SCHEDULED_TASK_CONFIG = {
    WEEKDAY_MONDAY: {
        "task_type": TaskType.tech_radar,
        "title": "产品与战略雷达",
        "subtitle": "产品、功能、技术路线、法规与具身产品信号",
        "suggested_action": SuggestedAction.generate_weekly_radar,
        "radar_type": RadarType.product_strategy_radar,
    },
    WEEKDAY_TUESDAY: {
        "task_type": TaskType.tech_radar,
        "title": "技术方法雷达",
        "subtitle": "WM、生成式驾驶视频、3D/4D、仿真与具身智能方法",
        "suggested_action": SuggestedAction.generate_weekly_radar,
        "radar_type": RadarType.technical_method_radar,
    },
    WEEKDAY_WEDNESDAY: {
        "task_type": TaskType.jd_analysis,
        "title": "JD 与职业能力分析",
        "subtitle": "岗位、结构化简历、能力差距与学习任务联动",
        "suggested_action": SuggestedAction.add_jd_input,
    },
    WEEKDAY_THURSDAY: {
        "task_type": TaskType.research_feeder,
        "title": "研究阅读启动",
        "subtitle": "选择主论文与候选论文，开始精读",
        "suggested_action": SuggestedAction.generate_reading_pack,
        "research_day_role": ResearchDayRole.select_and_start,
    },
    WEEKDAY_FRIDAY: {
        "task_type": TaskType.research_feeder,
        "title": "研究阅读归档",
        "subtitle": "补读、讨论、整理并归档主论文",
        "suggested_action": SuggestedAction.continue_reading,
        "research_day_role": ResearchDayRole.continue_and_archive,
    },
}

