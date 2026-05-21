// 等级经验值配置表（葫芦侠风格）
const LEVEL_CONFIG = [
	{ level: 1, exp: 0, title: '初来乍到' },
	{ level: 2, exp: 100, title: '略知一二' },
	{ level: 3, exp: 300, title: '崭露头角' },
	{ level: 4, exp: 600, title: '小有名气' },
	{ level: 5, exp: 1000, title: '声名远扬' },
	{ level: 6, exp: 1800, title: '如雷贯耳' },
	{ level: 7, exp: 3000, title: '名震一方' },
	{ level: 8, exp: 5000, title: '威震天下' },
	{ level: 9, exp: 8000, title: '独步江湖' },
	{ level: 10, exp: 12000, title: '登峰造极' },
	{ level: 11, exp: 18000, title: '超凡入圣' },
	{ level: 12, exp: 26000, title: '返璞归真' },
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

// 获取等级信息
function getLevelInfo(exp) {
	let current = LEVEL_CONFIG[0]
	let next = LEVEL_CONFIG[1] || null
	for (let i = LEVEL_CONFIG.length - 1; i >= 0; i--) {
		if (exp >= LEVEL_CONFIG[i].exp) {
			current = LEVEL_CONFIG[i]
			next = LEVEL_CONFIG[i + 1] || null
			break
		}
	}
	return {
		level: current.level,
		title: current.title,
		currentExp: exp - current.exp,
		levelExp: current.exp,
		nextLevelExp: next ? next.exp : null,
		needExp: next ? next.exp - exp : 0,
		progress: next ? (exp - current.exp) / (next.exp - current.exp) : 1.0,
	}
}

module.exports = { LEVEL_CONFIG, EXP_RULES, getLevelInfo }
