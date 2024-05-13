using UnityEditor;

[CustomEditor(typeof(ModelGrass))]
public class ModelGrassEditor : Editor
{
    private ModelGrass _myScript;

    // We need to use and to call an instnace of the default MaterialEditor
    private MaterialEditor _materialEditor; 

    void OnEnable ()
    {
        _myScript = (ModelGrass)target;

        if (_myScript.material != null) {
            // Create an instance of the default MaterialEditor
            _materialEditor = (MaterialEditor)CreateEditor (_myScript.material);
        }
    }

    public override void OnInspectorGUI ()
    {
        EditorGUI.BeginChangeCheck ();
        base.OnInspectorGUI();

        // Draw the material field of MyScript
        EditorGUILayout.PropertyField (serializedObject.FindProperty ("material"));

        if (EditorGUI.EndChangeCheck ()) {
            serializedObject.ApplyModifiedProperties (); 

            if (_materialEditor != null) {
                // Free the memory used by the previous MaterialEditor
                DestroyImmediate (_materialEditor);
            }

            if (_myScript.material != null) {
                // Create a new instance of the default MaterialEditor
                _materialEditor = (MaterialEditor)CreateEditor (_myScript.material);

            }
        }


        if (_materialEditor != null) {
            // Draw the material's foldout and the material shader field
            // Required to call _materialEditor.OnInspectorGUI ();
            _materialEditor.DrawHeader (); 
		
            //  We need to prevent the user to edit Unity default materials
            bool isDefaultMaterial = !AssetDatabase.GetAssetPath (_myScript.material).StartsWith ("Assets");

            using (new EditorGUI.DisabledGroupScope(isDefaultMaterial)) {

                // Draw the material properties
                // Works only if the foldout of _materialEditor.DrawHeader () is open
                _materialEditor.OnInspectorGUI (); 
            }
        }
    }

    void OnDisable ()
    {
        if (_materialEditor != null) {
            // Free the memory used by default MaterialEditor
            DestroyImmediate (_materialEditor);
        }
    }
}