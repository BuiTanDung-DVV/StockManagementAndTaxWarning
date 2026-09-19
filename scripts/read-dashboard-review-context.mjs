import fs from 'node:fs';
const files={screen:'lib/features/dashboard/presentation/dashboard_screen.dart',widgets:'lib/features/dashboard/presentation/widgets/dashboard_widgets.dart',insights:'lib/features/dashboard/presentation/widgets/dashboard_insights_widgets.dart',chart:'lib/core/widgets/chart_widgets.dart',test:'test/widget/dashboard_theme_regression_test.dart'};
const [key,startRaw='1']=process.argv.slice(2);
if(!Object.hasOwn(files,key))throw Error('Unknown source');
const start=Number(startRaw);if(!Number.isInteger(start)||start<1)throw Error('Invalid line');
console.log(fs.readFileSync(files[key],'utf8').split(/\r?\n/).slice(start-1,start+118).map((line,i)=>`${start+i}: ${line}`).join('\n'));
