require('dotenv').config()

module.exports = {
	PORT: process.env.PORT || 3000,
	JWT_SECRET: process.env.JWT_SECRET || 'liubi_secret',
	ADMIN_USER: process.env.ADMIN_USER || 'admin',
	ADMIN_PASS: process.env.ADMIN_PASS || 'admin123',
}
