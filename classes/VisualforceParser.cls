public with sharing class VisualforceParser {

    private static final String NAME = 'Name';
    private static final String MARKUP = 'Markup';
    private static final String COMMA = ',';

    private static final String REGULAR_STANDARD_CONTROLLER_NAME = '(?i)([\\s]standardcontroller=")([\\w]+)"{1}';
    private static final String REGULAR_CONTROLLER_NAME = '(?i)([\\s]controller=")([\\w]+)"{1}';
    private static final String REGULAR_EXTENSIONS_NAMES = '(?i)([\\s]extensions=")([\\w,]+)"{1}';
    private static final String REGULAR_ACTION = '(?i)([\\s]action="\\{!)([\\w]+)(\\}"){1}';
    private static final String GET_METHOD = '(\\{!){1}([\\w]+)(}){1}';

    private static final Pattern PATTERN_STANDARD_CONTROLLER_NAME =  Pattern.compile(REGULAR_STANDARD_CONTROLLER_NAME);
    private static final Pattern PATTERN_CONTROLLER_NAME =  Pattern.compile(REGULAR_CONTROLLER_NAME);
    private static final Pattern PATTERN_EXTENSIONS_NAMES = Pattern.compile(REGULAR_EXTENSIONS_NAMES);
    private static final Pattern PATTERN_ACTION = Pattern.compile(REGULAR_ACTION);
    private static final Pattern PATTERN_GET_METHOD = Pattern.compile(GET_METHOD);


    private List<ApexPage> vPages;
    private List<ApexComponent> vComponents;

    public VisualforceParser() {
        vPages = [SELECT Name, Markup FROM ApexPage WHERE NamespacePrefix = null];
        vComponents = [SELECT Name, Markup FROM ApexComponent WHERE NamespacePrefix = null];
    }

    public void parseVisualforce(Map<String, ClassMethod__c> classMethodMap) {
        parseListOfVisualforceElements(vPages, classMethodMap, true);
        parseListOfVisualforceElements(vComponents, classMethodMap, false);
    }

    private void parseListOfVisualforceElements(List<SObject> vElements, Map<String, ClassMethod__c> classMethodMap, Boolean isPage) {
        Matcher standardControllerM;
        Matcher controllerM;
        Matcher extensionsM;
        Matcher actionM;
        Matcher getMethodM;

        Boolean isFindStandardController;
        Boolean isFindController;
        Boolean isFindExtensions;    

        String[] controllerExtList;
        Set<String> actionSet;

        for(SObject element : vElements) {

            standardControllerM = PATTERN_STANDARD_CONTROLLER_NAME.matcher( (String) element.get(MARKUP) );
            controllerM = PATTERN_CONTROLLER_NAME.matcher( (String) element.get(MARKUP) );
            extensionsM = PATTERN_EXTENSIONS_NAMES.matcher( (String) element.get(MARKUP) );
            actionM = PATTERN_ACTION.matcher( (String) element.get(MARKUP) );
            getMethodM = PATTERN_GET_METHOD.matcher( (String) element.get(MARKUP) );


            isFindStandardController = standardControllerM.find();
            isFindController = controllerM.find();
            isFindExtensions = extensionsM.find();    

            controllerExtList = new List<String>();
            actionSet = new Set<String>();   

            if (isFindController && isFindExtensions) {

                controllerExtList.addAll(extensionsM.group(2).split(COMMA));
                controllerExtList.add(controllerM.group(2));
                findActionsOnElement(actionM, actionSet);
                findGetMethodsOnElement(getMethodM, actionSet);
                findClassMethodByAction(actionSet, controllerExtList, classMethodMap, (String) element.get(NAME), isPage);      

            } else if (isFindStandardController && isFindExtensions) {

                controllerExtList.addAll(extensionsM.group(2).split(COMMA));
                controllerExtList.add(standardControllerM.group(2));
                findActionsOnElement(actionM, actionSet);
                findGetMethodsOnElement(getMethodM, actionSet);
                findClassMethodByAction(actionSet, controllerExtList, classMethodMap, (String) element.get(NAME), isPage);

            } else if (isFindController) {

                controllerExtList.add(controllerM.group(2));
                findActionsOnElement(actionM, actionSet);
                findGetMethodsOnElement(getMethodM, actionSet);
                findClassMethodByAction(actionSet, controllerExtList, classMethodMap, (String) element.get(NAME), isPage);                                                                            
            } 
        }
    }

    private void findActionsOnElement(Matcher actionM, Set<String> actionSet) {
        while (actionM.find()) {
            actionSet.add(actionM.group(2) + '()');
        }
    }

    private void findGetMethodsOnElement(Matcher getMethodM, Set<String> actionSet) {
        while (getMethodM.find()) {
            actionSet.add('get' + getMethodM.group(2) + '()');
        }
    }

    private void findClassMethodByAction(Set<String> actionSet, String[] controllerExtList, Map<String, ClassMethod__c> classMethodMap, String elementName, Boolean isPage) {
        Boolean stop;
        Integer i;
        String controllerExtName;
        String uniqueClassMethodField;
        ClassMethod__c classMethod;
        for (String actionName : actionSet) {
            stop = false;
            i = 0;
            while (!stop) {
                controllerExtName = controllerExtList[i++];
                uniqueClassMethodField = controllerExtName + '.' + actionName;
                uniqueClassMethodField = uniqueClassMethodField.toLowerCase();
                if (classMethodMap.containsKey(uniqueClassMethodField)) {
                    classMethod = classMethodMap.get(uniqueClassMethodField);
                    if (isPage) {
                        if (classMethod.Visualforce_Pages__c == null) {
                            classMethod.Visualforce_Pages__c = elementName;
                        } else {
                            classMethod.Visualforce_Pages__c += COMMA + ' ' + elementName;
                        }
                    } else {
                        if (classMethod.Visualforce_Components__c == null) {
                            classMethod.Visualforce_Components__c = elementName;
                        } else {
                            classMethod.Visualforce_Components__c += COMMA + ' ' + elementName;
                        }
                    }
                    stop = true;
                }
                if (i == controllerExtList.size()) {
                    stop = true;
                }
            }
        }
    }

}