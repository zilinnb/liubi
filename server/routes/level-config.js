// 等级经验值配置表（葫芦侠风格）
// exp: 累计经验阈值（从level_config表读取时以exp_to_next为准动态计算）
// exp_to_next: 从当前等级升到下一级需要的经验增量
const LEVEL_CONFIG = [
	{ level: 1, exp: 0, title: '初来乍到', exp_to_next: 50 },
	{ level: 2, exp: 50, title: '略知一二', exp_to_next: 150 },
	{ level: 3, exp: 200, title: '崭露头角', exp_to_next: 300 },
	{ level: 4, exp: 500, title: '小有名气', exp_to_next: 500 },
	{ level: 5, exp: 1000, title: '声名远扬', exp_to_next: 800 },
	{ level: 6, exp: 1800, title: '如雷贯耳', exp_to_next: 1200 },
	{ level: 7, exp: 3000, title: '名震一方', exp_to_next: 2000 },
	{ level: 8, exp: 5000, title: '威震天下', exp_to_next: 3000 },
	{ level: 9, exp: 8000, title: '独步江湖', exp_to_next: 4000 },
	{ level: 10, exp: 12000, title: '登峰造极', exp_to_next: 6000 },
	{ level: 11, exp: 18000, title: '超凡入圣', exp_to_next: 8000 },
	{ level: 12, exp: 26000, title: '返璞归真', exp_to_next: 0 },
]

// 经验值获取规则
const EXP_RULES = {
	post: 10,
	comment: 3,
	like_given: 1,
	liked: 2,
	view: 0.1,
	checkin: 5,
	chat: 1,
}

// 获取等级信息（支持动态配置）
function getLevelInfo(exp, customConfig) {
	const config = customConfig || LEVEL_CONFIG
	let current = config[0]
	let next = config[1] || null
	for (let i = config.length - 1; i >= 0; i--) {
		if (exp >= config[i].exp) {
			current = config[i]
			next = config[i + 1] || null
			break
		}
	}
	const expToNext = current.exp_to_next || (next ? next.exp - current.exp : 0)
	return {
		level: current.level,
		title: current.title,
		currentExp: exp - current.exp,
		levelExp: current.exp,
		nextLevelExp: next ? next.exp : null,
		expToNext: expToNext,
		needExp: next ? next.exp - exp : 0,
		progress: next && expToNext > 0 ? (exp - current.exp) / expToNext : 1.0,
	}
}

module.exports = { LEVEL_CONFIG, EXP_RULES, getLevelInfo }
