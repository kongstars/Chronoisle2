// 应用主题配置 - 科技感风格
export const AppTheme = {
  // 主色调 - 蓝紫渐变
  primary: {
    light: '#667EEA',
    main: '#5A67D8',
    dark: '#4C51BF',
    gradient: ['#667EEA', '#764BA2']
  },
  
  // 强调色 - 荧光绿
  accent: {
    light: '#68D391',
    main: '#48BB78',
    dark: '#38A169',
    neon: '#00FFA3'
  },
  
  // 背景色 - 深色渐变
  background: {
    primary: '#0F0F23',
    secondary: '#1A1A2E',
    card: '#16213E',
    cardLight: '#1F2947'
  },
  
  // 文字颜色
  text: {
    primary: '#FFFFFF',
    secondary: '#E2E8F0',
    muted: '#A0AEC0',
    disabled: '#718096'
  },
  
  // 分类颜色 - 霓虹风格
  categories: {
    career: '#FF6B6B',      // 事业 - 霓虹红
    health: '#4ECDC4',      // 健康 - 青绿
    learning: '#45B7D1',    // 学习 - 天蓝
    finance: '#FFA502',     // 理财 - 橙色
    social: '#A55EEA',      // 社交 - 紫色
    family: '#FF85A2',      // 家庭 - 粉色
    growth: '#26DE81',      // 成长 - 荧光绿
    fun: '#FD9644'          // 娱乐 - 橘黄
  },
  
  // 阴影效果
  shadows: {
    small: {
      radius: 8,
      color: 'rgba(0, 0, 0, 0.3)',
      offsetX: 0,
      offsetY: 4
    },
    medium: {
      radius: 16,
      color: 'rgba(0, 0, 0, 0.4)',
      offsetX: 0,
      offsetY: 8
    },
    large: {
      radius: 24,
      color: 'rgba(0, 0, 0, 0.5)',
      offsetX: 0,
      offsetY: 12
    },
    glow: {
      radius: 20,
      color: 'rgba(102, 126, 234, 0.4)',
      offsetX: 0,
      offsetY: 0
    }
  },
  
  // 圆角
  radius: {
    small: 8,
    medium: 12,
    large: 16,
    xl: 24,
    full: 999
  },
  
  // 间距
  spacing: {
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32
  },
  
  // 字体大小
  fontSize: {
    xs: 10,
    sm: 12,
    md: 14,
    lg: 16,
    xl: 20,
    xxl: 24,
    xxxl: 32
  }
};

// 渐变背景配置
export const Gradients = {
  // 主渐变
  primary: 'linear-gradient(135deg, #667EEA 0%, #764BA2 100%)',
  
  // 卡片渐变
  card: 'linear-gradient(145deg, #16213E 0%, #1A1A2E 100%)',
  
  // 强调渐变
  accent: 'linear-gradient(135deg, #48BB78 0%, #38A169 100%)',
  
  // 危险渐变
  danger: 'linear-gradient(135deg, #F56565 0%, #C53030 100%)'
};

// 动画配置
export const Animations = {
  duration: {
    fast: 200,
    normal: 300,
    slow: 500
  },
  
  ease: {
    in: 'cubic-bezier(0.4, 0, 1, 1)',
    out: 'cubic-bezier(0, 0, 0.2, 1)',
    inOut: 'cubic-bezier(0.4, 0, 0.2, 1)'
  }
};
