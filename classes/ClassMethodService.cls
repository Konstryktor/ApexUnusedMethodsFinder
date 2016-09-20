public with sharing class ClassMethodService implements Queueable,  Database.AllowsCallouts  { 
       
    private ToolingAPI tooling = new ToolingAPI();
    private VisualforceParser vp = new VisualforceParser();

    private List<ToolingAPI.ApexTriggerMember> triggerMemberList;
    private List<ToolingAPI.ApexClassMember> classMemberList;

    private List<ApexClass> apexClassList;
    private Map<String, String> callsFromApex = new Map<String, String>();
    private Map<String, String> callsFromTriggers = new Map<String, String>();
    private Map<String, ClassMethod__c> recordsList = new Map<String, ClassMethod__c>();

    private ToolingAPI.SymbolTable symbolTable;

    private ClassMethod__c classMethod;

    private static final String COMMA = ',';
    private static final String SPACE = ' ';

    private String className;
    private String methodName;
    private String classMethodParams;
    private String modifiers;
    private String uniqueClassMethodField;
    private String overloadCallList;
    private String callList;
    private String testClassNames;

    public ClassMethodService() {}

    public void execute(QueueableContext context) {

        triggerMemberList  = (List<ToolingAPI.ApexTriggerMember>) tooling.query('SELECT ContentEntityId, ContentEntity.Name, SymbolTable ' + 
                                                                                'FROM ApexTriggerMember').records;
        classMemberList  = (List<ToolingAPI.ApexClassMember>) tooling.query('SELECT ContentEntityId, ContentEntity.Name, SymbolTable ' + 
                                                                            'FROM ApexClassMember').records; 

        if (classMemberList != null) {
            for (ToolingAPI.ApexClassMember acm : classMemberList) {
                symbolTable = acm.symbolTable;
                if (symbolTable == null) {
                    continue;
                }
                for (ToolingAPI.Method method : symbolTable.methods) {            
                    setClassMethodDataThenCreatePut(symbolTable.name, method.name, parametersToString(method.parameters), 
                                                    modifiersOrInterfacesToString(method.modifiers),
                                                    modifiersOrInterfacesToString(symbolTable.interfaces));
                    if ( (method.references != null) && (!method.references.isEmpty()) ) {        
                        addMethodCallToMap(uniqueClassMethodField, className, callsFromApex);    
                    }
                }
                addExternalMethodsCalls(symbolTable, callsFromApex);
            }

            if (triggerMemberList != null) {
                for (ToolingAPI.ApexTriggerMember atm : triggerMemberList) {        
                    symbolTable = atm.symbolTable;
                    if (symbolTable == null) {
                        continue;
                    }
                    className = symbolTable.name;
                    addExternalMethodsCalls(symbolTable, callsFromTriggers);
                } 
            }

            vp.parseVisualforce(recordsList);

            for (String cm : recordsList.keySet()) { 
                classMethod = recordsList.get(cm);
                addCallListForClassMethod(cm, classMethod, callsFromApex, true);
                addCallListForClassMethod(cm, classMethod, callsFromTriggers, false);
                countUsage(cm, classMethod);
            } 
            delete [SELECT Name FROM ClassMethod__c];
            insert recordsList.values();      
        }
    }

    // find methods that are called only in scope of classes where type 'Apex Class' 
    public static void findPotentialUnusedMethods() {

        List<ClassMethod__c> classMethodList = [SELECT Apex_Classes__c, Class_Name__c, Method_Name__c, Potential_Unused__c  
                                                FROM ClassMethod__c
                                                WHERE Type__c = 'Apex Class' AND Used__c = true];
        List<ClassMethod__c> notApexClassTypeMethodList = [SELECT Apex_Classes__c, Class_Name__c, Method_Name__c, Potential_Unused__c  
                                                           FROM ClassMethod__c
                                                           WHERE Type__c != 'Apex Class'];
        Set<String> notApexClassTypeMethodSet = makeClassNameSetFromClassMethodList(notApexClassTypeMethodList);
        Map<String, List<String>> classMap = makeClassMapFromClassMethodList(classMethodList);
        for (ClassMethod__c cm : classMethodList) {
            checkClassMethod(cm, classMap, notApexClassTypeMethodSet);
        }
        update classMethodList;
    }
    
    public static void findUnusedClasses() {
        List<ClassMethod__c> classMethodList = [SELECT Apex_Classes__c, Class_Name__c, Method_Name__c, Used__c, Type__c  
                                                FROM ClassMethod__c];
        Map<String, List<ClassMethod__c>> classMap = new Map<String, List<ClassMethod__c>>();
        for (ClassMethod__c cm : classMethodList) {
            if (classMap.containsKey(cm.Class_Name__c)) {
                classMap.get(cm.Class_Name__c).add(cm);
            } else {
                classMap.put(cm.Class_Name__c, new List<ClassMethod__c>{cm});
            }
        }
        Boolean result;
        Integer i;
        for (List<ClassMethod__c> listCM : classMap.values()) {
            result = false;
            i = 0; 
            for (ClassMethod__c cm : listCM) {
                if ( (cm.Used__c == false) && (cm.Type__c == 'Apex Class') ) {
                    i++;
                }
            }
            if (i == listCM.size()) {
                result = true;
            } 
            for (ClassMethod__c cm : listCM) {
                cm.InUnusedClass__c = result;
            }
        }
        update classMethodList;
    }

    //check class method for potential unsued
    private static void checkClassMethod(ClassMethod__c classMethod, Map<String, List<String>> classMap, Set<String> notApexClassTypeMethodSet ) {

        List<String> callList = classMethod.Apex_Classes__c.remove(' ').split(',');
        Set<String> copyList = new Set<String>();
        copyList.addAll(callList);
        Integer i = 0;
        String className;
        while (true) {
            className = callList[i++];
            if ( (classMap.containsKey(className)) && (!notApexClassTypeMethodSet.contains(className)) ) {
                List<String> externalCallList = classMap.get(className);
                for (String externalClassName : externalCallList) {
                    if (!copyList.contains(externalClassName)) {
                        copyList.add(externalClassName);
                        callList.add(externalClassName);
                    }
                }
                if (callList.size() == i) {
                    classMethod.Potential_Unused__c = true;
                    break;
                }
            } else {
                classMethod.Potential_Unused__c = false;
                break;                
            }
        }
    }

    // make from ClassMethod(where type != 'Apex Class') list --> set of All Class names
    private static Set<String> makeClassNameSetFromClassMethodList(List<ClassMethod__c> notApexClassTypeMethodList) {

        Set<String> notApexClassTypeMethodSet = new Set<String>();
        for (ClassMethod__c cm : notApexClassTypeMethodList) {
            notApexClassTypeMethodSet.add(cm.Class_Name__c);
        }
        return notApexClassTypeMethodSet;
    }

    //make from  ClassMethod list --> map, where key = 'ClassName', value = 'list of Class methods'
    private static Map<String, List<String>> makeClassMapFromClassMethodList(List<ClassMethod__c> classMethodList) {

        Map<String, List<String>> classMap = new Map<String, List<String>>();
        for (ClassMethod__c cm : classMethodList) {
            if (classMap.containsKey(cm.Class_Name__c)) {
                classMap.get(cm.Class_Name__c).addAll(cm.Apex_Classes__c.remove(' ').split(','));
            } else {
                classMap.put(cm.Class_Name__c, cm.Apex_Classes__c.remove(' ').split(','));
            }
        }
        return classMap;
    }

    // count how many different triggers/visualforce elements/summ call this classMethod
    private void countUsage(String uniqueClassMethodField, ClassMethod__c classMethod) {

        Integer count = 0;
        Integer visualforceCount = 0;
        Integer triggersCount = 0;
        if (classMethod.Apex_Classes__c != null) {
            count = classMethod.Apex_Classes__c.countMatches(COMMA) + 1;
        } 
        if (classMethod.Apex_Triggers__c != null) { 
            count += classMethod.Apex_Triggers__c.countMatches(COMMA) + 1;
            triggersCount = classMethod.Apex_Triggers__c.countMatches(COMMA) + 1;
        } 
        if (classMethod.Visualforce_Pages__c != null) {
            count += classMethod.Visualforce_Pages__c.countMatches(COMMA) + 1;
            visualforceCount += classMethod.Visualforce_Pages__c.countMatches(COMMA) + 1;
        }
        if (classMethod.Visualforce_Components__c != null) {
            count += classMethod.Visualforce_Components__c.countMatches(COMMA) + 1;
            visualforceCount += classMethod.Visualforce_Components__c.countMatches(COMMA) + 1;
        }
        classMethod.Number_of_Usage__c = count;
        classMethod.Visualforce__c = visualforceCount;
        classMethod.Triggers_count__c = triggersCount;
    }

    // add to classMethod lists of Apex Classes and Apex Triggers where this method are called
    private void addCallListForClassMethod(String uniqueClassMethodField, ClassMethod__c classMethod, Map<String, String> callsMap, Boolean isCallsFromApex) {

        callList = callsMap.get(uniqueClassMethodField);         
        overloadCallList = callsMap.get(uniqueClassMethodField.substringBefore('(') + '()');
        if (overloadCallList != null) {
            if ( (callList != null) && (callList != overloadCallList) ) {
                callList = callList + COMMA + SPACE + overloadCallList;
            } else {
                callList = overloadCallList;
            }
        }
        if (isCallsFromApex) {
            classMethod.Apex_Classes__c = callList;
        } else {
            classMethod.Apex_Triggers__c = callList;
        }       
    }

    //  add to map methods that are called in external classes
    private void addExternalMethodsCalls(ToolingAPI.SymbolTable symbolTable, Map<String, String> callsMap) {

        for (ToolingAPI.ExternalReference externalRef : symbolTable.externalReferences) {
            for (ToolingApi.ExternalMethod externalMethodRef : externalRef.methods) {
                uniqueClassMethodField = externalRef.name + '.' + externalMethodRef.name + parametersToString(externalMethodRef.parameters);
                uniqueClassMethodField = uniqueClassMethodField.toLowerCase();                
                addMethodCallToMap(uniqueClassMethodField, className, callsMap);
            }   
        }
    }

    // set to variables data of current classMethod, create ClassMethod and put him to recordsMap
    private void setClassMethodDataThenCreatePut(String cName, String mName, String params, String modif, String interfaces) {

        className = cName;
        methodName = mName;
        classMethodParams = params;
        modifiers = modif;
        uniqueClassMethodField = className + '.' + methodName + classMethodParams;
        uniqueClassMethodField = uniqueClassMethodField.toLowerCase();
        recordsList.put(uniqueClassMethodField, new ClassMethod__c(Class_Name__c = className, Method_Name__c = methodName, Modifiers__c = modifiers,
                                                                   Parameters__c = classMethodParams, Unique_Field__c = uniqueClassMethodField, 
                                                                   Interfaces__c = interfaces, Number_of_Usage__c = 0));
    }

    //  add to map methods that are called in his classes
    private void addMethodCallToMap(String uniqueClassMethodField, String className, Map<String, String> callsMap) {

        if (callsMap.containsKey(uniqueClassMethodField)) {
            callsMap.put(uniqueClassMethodField, callsMap.get(uniqueClassMethodField) + COMMA + SPACE + className);
        } else {
            callsMap.put(uniqueClassMethodField, className);
        }
    }

    // toString list of method parameters (... , ... , ...) 
    private String parametersToString(List<ToolingAPI.Parameter> parameters) {

        String result = '(';
        for(ToolingAPI.Parameter param : parameters) {
            if(result.length() > 1) {
                result += COMMA + SPACE;
            }
            result += param.type + SPACE + param.name;
        }
        result += ')';
        return result;
    }

    // toString list of modifiers or Interfaces ... , ... , ...
    private String modifiersOrInterfacesToString(List<String>  modifiersArr) {

        String result = '';
        for (String str : modifiersArr) {
            if(result.length() > 1) {
                result += COMMA + SPACE;
            }
            result += str;
        }
        return result;
    }
}