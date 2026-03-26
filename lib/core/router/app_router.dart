import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/sales/presentation/sales_list_screen.dart';
import '../../features/sales/presentation/pos_screen.dart';
import '../../features/sales/presentation/order_detail_screen.dart';
import '../../features/products/presentation/product_list_screen.dart';
import '../../features/products/presentation/product_detail_screen.dart';
import '../../features/customers/presentation/customer_list_screen.dart';
import '../../features/customers/presentation/customer_detail_screen.dart';
import '../../features/suppliers/presentation/supplier_list_screen.dart';
import '../../features/suppliers/presentation/supplier_detail_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/inventory/presentation/stock_take_screen.dart';
import '../../features/inventory/presentation/purchase_order_screen.dart';
import '../../features/finance/presentation/finance_screen.dart';
import '../../features/finance/presentation/daily_closing_screen.dart';
import '../../features/finance/presentation/profit_loss_screen.dart';
import '../../features/finance/presentation/cashflow_forecast_screen.dart';
import '../../features/finance/presentation/debt_aging_screen.dart';
import '../../features/finance/presentation/invoice_list_screen.dart';
import '../../features/finance/presentation/purchase_no_invoice_screen.dart';
import '../../features/inventory/presentation/xnt_report_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/activity_log_screen.dart';
import '../../features/settings/presentation/tax_config_screen.dart';
import '../../features/settings/presentation/tax_support_screen.dart';
import '../../features/settings/presentation/payment_config_screen.dart';
import '../../features/finance/presentation/tax_calculator_screen.dart';
import '../../features/finance/presentation/expense_ledger_screen.dart';
import '../../features/finance/presentation/tax_obligation_screen.dart';
import '../../features/finance/presentation/salary_ledger_screen.dart';
import '../../features/finance/presentation/tax_declaration_screen.dart';
import '../../features/finance/presentation/transaction_history_screen.dart';

import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
    GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (_, _, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
        // Sales
        GoRoute(path: '/sales', builder: (_, _) => const SalesListScreen()),
        GoRoute(path: '/pos', builder: (_, _) => const PosScreen()),
        GoRoute(path: '/sales/:id', builder: (_, state) => OrderDetailScreen(id: int.parse(state.pathParameters['id']!))),
        // Products
        GoRoute(path: '/products', builder: (_, _) => const ProductListScreen()),
        GoRoute(path: '/products/:id', builder: (_, state) => ProductDetailScreen(id: int.parse(state.pathParameters['id']!))),
        // Customers
        GoRoute(path: '/customers', builder: (_, _) => const CustomerListScreen()),
        GoRoute(path: '/customers/:id', builder: (_, state) => CustomerDetailScreen(id: int.parse(state.pathParameters['id']!))),
        // Suppliers
        GoRoute(path: '/suppliers', builder: (_, _) => const SupplierListScreen()),
        GoRoute(path: '/suppliers/:id', builder: (_, state) => SupplierDetailScreen(id: int.parse(state.pathParameters['id']!))),
        // Inventory
        GoRoute(path: '/inventory', builder: (_, _) => const InventoryScreen()),
        GoRoute(path: '/stock-take', builder: (_, _) => const StockTakeScreen()),
        GoRoute(path: '/purchase-orders', builder: (_, _) => const PurchaseOrderScreen()),
        GoRoute(path: '/xnt-report', builder: (_, _) => const XntReportScreen()),
        // Finance
        GoRoute(path: '/finance', builder: (_, _) => const FinanceScreen()),
        GoRoute(path: '/daily-closing', builder: (_, _) => const DailyClosingScreen()),
        GoRoute(path: '/profit-loss', builder: (_, _) => const ProfitLossScreen()),
        GoRoute(path: '/cashflow-forecast', builder: (_, _) => const CashflowForecastScreen()),
        GoRoute(path: '/debt-aging', builder: (_, _) => const DebtAgingScreen()),
        GoRoute(path: '/invoices', builder: (_, _) => const InvoiceListScreen()),
        GoRoute(path: '/purchases-no-invoice', builder: (_, _) => const PurchaseNoInvoiceScreen()),
        GoRoute(path: '/tax-calculator', builder: (_, _) => const TaxCalculatorScreen()),
        GoRoute(path: '/expense-ledger', builder: (_, _) => const ExpenseLedgerScreen()),
        GoRoute(path: '/tax-obligations', builder: (_, _) => const TaxObligationScreen()),
        GoRoute(path: '/salary-ledger', builder: (_, _) => const SalaryLedgerScreen()),
        GoRoute(path: '/tax-declaration', builder: (_, _) => const TaxDeclarationScreen()),
        GoRoute(path: '/transactions', builder: (_, _) => const TransactionHistoryScreen()),
        // Settings
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(path: '/activity-logs', builder: (_, _) => const ActivityLogScreen()),
        GoRoute(path: '/tax-config', builder: (_, _) => const TaxConfigScreen()),
        GoRoute(path: '/tax-support', builder: (_, _) => const TaxSupportScreen()),
        GoRoute(path: '/payment-config', builder: (_, _) => const PaymentConfigScreen()),
      ],
    ),
  ],
);
