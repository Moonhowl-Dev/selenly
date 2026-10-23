// ESLint configuration (flat config): https://eslint.org/docs/latest/use/configure/
import js from '@eslint/js'
import pluginQuery from '@tanstack/eslint-plugin-query'
import pluginRouter from '@tanstack/eslint-plugin-router'
import prettier from 'eslint-config-prettier/flat'
import jsxA11y from 'eslint-plugin-jsx-a11y'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import { defineConfig, globalIgnores } from 'eslint/config'
import globals from 'globals'
import tseslint from 'typescript-eslint'

export default defineConfig([
  // Generated code and build output are never linted.
  globalIgnores(['dist', 'coverage', 'src/app/routeTree.gen.ts', 'src/api']),

  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      js.configs.recommended,
      // Type-aware rules, e.g. a forgotten await on a promise (common with mutations).
      tseslint.configs.recommendedTypeChecked,
      reactHooks.configs.flat['recommended-latest'],
      reactRefresh.configs.vite,
      // Accessibility: the plan's goal is Lighthouse accessibility 100.
      jsxA11y.flatConfigs.strict,
      pluginQuery.configs['flat/recommended'],
      pluginRouter.configs['flat/recommended'],
      // Last: turns off rules that would fight with Prettier's formatting.
      prettier,
    ],
    languageOptions: {
      ecmaVersion: 2023,
      globals: globals.browser,
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },

  {
    // Route files export a Route object and the TanStack plugin handles their hot reload;
    // shadcn/ui components export style helpers (e.g. buttonVariants) next to the component.
    files: ['src/routes/**', 'src/shared/ui/**'],
    rules: {
      'react-refresh/only-export-components': 'off',
    },
  },
])
